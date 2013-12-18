
require "sinatra"
use Rack::CommonLogger
require 'sinatra/contrib/all'
require 'sinatra/partial'
require 'sinatra/static_assets'
require 'sinatra-env'
require 'haml'
require 'httparty'
require 'active_support/core_ext/string'
require 'will_paginate'
require 'will_paginate/array'
require "will_paginate-bootstrap"


module ApplicationHelper
  def asset_server()
    server = (Sinatra.env.development?)? 'http://localhost:4567' : 'http://sic-assets.metrik.cl'
    return server
  end

  def generate_url(type, value)
    return "#" if type == 'domain' && @domains.length == 1
    return "#" if type == 'rtype' && @types.length == 1
    url = "/search.html?query=#{@query}"
    url << "&type=#{@rtype}" unless @rtype.blank?
    url << "&domain=#{@domain}" unless @domain.blank?
    url << "&#{type}=#{value}"
    return url
  end

  def params_for_will_paginate()
    params = {}
    params.merge!({:domain => @domain}) unless @domain.blank?
    params.merge!({:rtype => @rtype}) unless @rtype.blank?
    return params
  end

end

class MySinatra < Sinatra::Base
  register Sinatra::Contrib
  register Sinatra::Partial
  register Sinatra::StaticAssets
  include WillPaginate::Sinatra::Helpers
  helpers ApplicationHelper

require "nokogiri"

  get "/" do

  end
  get "/search.html" do
  
    if params[:page].blank? || params[:page].to_i <1
      @page =  1
    else
      @page = params[:page].to_i
    end
    @per_page = 30
    indx = @per_page*(@page-1)+1
    options = "indx=#{indx}&bulkSize=#{@per_page}&institution=CONICYT&loc=local,scope:(conicyt_dspace,conicyt_scielocl)&loc=adaptor,primo_central_multiple_fe"
    @query = params[:query]
    @domain = params[:domain]
    @rtype = params[:type]
    options << "&query=any,contains,#{@query}"
    unless params[:domain].blank?
      options << "&query=facet_domain,exact,#{@domain}"
    end
    unless params[:type].blank?
      options << "&query=facet_rtype,exact,#{@rtype}"
    end

    #response = HTTParty.get('https://www.pcfactory.cl/', options)
    # return 'result'

    #CONSTRUIR LA url

    #PARA OBTENER EL xml SIN ESPACIOS NI SALTOS DE LINEA
    if  Sinatra.env.development?
      aux = File.read("primo.xml").gsub(/>\s+</,'><')
    else
      #Production
      encoded_url = URI.encode("http://primo.gsl.com.mx:1701/PrimoWebServices/xservice/search/brief?"+options)
      puts encoded_url
      response = HTTParty.get(encoded_url)
      puts response.body.to_yaml
      puts encoded_url

      aux = response.body.gsub(/>\s+</,'><')
    end
    doc = Nokogiri::XML(aux)
    
    basic = doc.xpath(".//xmlns:DOCSET")
    @total_results = basic.xpath(".//@TOTALHITS").first.value
    @total= @total_results.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse



    domain = doc.xpath(".//xmlns:FACET[@NAME='domain']")
    numero_de_dominios = domain.xpath('.//@COUNT').first.value

    domains   = domain.xpath(".//xmlns:FACET_VALUES")
    @domains  = domains.collect{|d| {:key => d.xpath('.//@KEY').first.value, :value => d.xpath('.//@VALUE').first.value}}.sort_by{|x| x[:key]}
    type     = doc.xpath(".//xmlns:FACET[@NAME='rtype']")
    types     = type.xpath(".//xmlns:FACET_VALUES")
    @types    = types.collect{|d| {:key => d.xpath('.//@KEY').first.value, :value => d.xpath('.//@VALUE').first.value}}.sort_by{|x| x[:key]}
    doc.remove_namespaces!
    record = doc.xpath(".//DOC")
    @records = record.collect{|r| {:title => r.xpath(".//display/title").first.text,
                                    :authors => (r.xpath(".//display/creator").first.blank?)? ' ' : r.xpath(".//display/creator").first.text.gsub(',',', '),
                                    :publisher => (r.xpath(".//display/publisher").first.blank?)? ' ': r.xpath(".//display/publisher").first.text,
                                    :creation_date => (r.xpath(".//display/creationdate").first.blank?)? ' ': r.xpath(".//display/creationdate").first.text,
                                    :volume => (r.xpath(".//display/version").first.blank?)? ' ': r.xpath(".//display/version").first.text,
                                    :description => (r.xpath(".//display/description").first.blank?)? ' ': r.xpath(".//display/description").first.text ,
                                    :src => r.xpath('.//LINKS').xpath('.//linktorsrc').text
                                  }
                              }
    @page_results = WillPaginate::Collection.create(@page, @per_page, @total_results) do |pager|
      pager.replace(@records)
    end


    haml :search
  end
end




