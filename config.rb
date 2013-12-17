
# Change Compass configuration
compass_config do |config|
  # routes for stylesheets directories at build mode
  config.sass_options = {:output_style => :nested, :images_dir => 'images', :fonts_dir => 'fonts'}
end

Encoding.default_external = 'utf-8'

# for physical directories at development mode
set :images_dir,  "images"
set :fonts_dir,  "fonts"
set :css_dir,  "stylesheets"
set :js_dir, "javascripts"

set :markdown, :layout_engine => :haml


set :default_encoding, 'utf-8'

# Build-specific configuration

configure :build do
  activate :compass

  activate :minify_css
  activate :minify_javascript

  # Use relative URLs
  activate :relative_assets

  # Enable cache buster
  # activate :cache_buster

  # Compress PNGs after build
  # First: gem install middleman-smusher
  # require "middleman-smusher"
  # activate :smusher

  # Or use a different image path
  #set :http_path, "./"

end

require "sinatra"
use Rack::CommonLogger
require 'sinatra/contrib/all'
require 'sinatra/partial'
require 'sinatra/static_assets'
require 'sinatra-env'
require 'haml'
require 'active_support/core_ext/string'
require 'will_paginate'
require 'will_paginate/array'


module ApplicationHelper
  def asset_server()
    server = (Sinatra.env.development?)? 'http://localhost:4567' : 'http://sic-assets.metrik.cl'
    return server

  
  end
  def generate_url(type, value)
    return "#" if type == 'domain' && @domains.length == 1
    return "#" if type == 'rtype' && @types.length == 1
    url = "/sinatra/search.html?query=#{@query}&page=#{@page}"
    url << "&rtype=#{@rtype}" unless @rtype.blank?
    url << "&domain=#{@domain}" unless @domain.blank?
    url << "&#{type}=#{value}"
    return url
  end

  def params_for_will_paginate()
    params = {:query  => @query}
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
  post "/search.html" do
  

    @page = params[:page] || 1
    @per_page = 30
    indx = @per_page*(@page-1)+1
    options = {:indx  => indx, :bulk_size => @per_page, :institution => 'CONICYT'}
    @query = params[:query]
    @domain = params[:domain]
    @rtype = params[:type]
    options.merge!({:query => "any,contains,#{@query}"})
    unless params[:domain].blank?
      options.merge!({:query => "facet_domain,exact,#{@domain}"})
    end
    unless params[:type].blank?
      options.merge!({:query => "facet_rtype,exact,#{@rtype}"})
    end

    #response = HTTParty.get('https://www.pcfactory.cl/', options)
    # return 'result'

    #CONSTRUIR LA url

    #PARA OBTENER EL xml SIN ESPACIOS NI SALTOS DE LINEA
    if Sinatra.env.development?
      aux = File.read("primo.xml").gsub(/>\s+</,'><')
    else
      #Production
      aux = HTTParty.get('http://primo.gsl.com.mx:1701/PrimoWebServices/xservice/search/brief', options).gsub(/>\s+</,'><')
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
    record = doc.xpath(".//record")
    @records = record.collect{|r| {:title => r.xpath(".//display/title").first.text,
                                    :authors => r.xpath(".//display/creator").first.text.gsub(',',', '),
                                    :publisher => r.xpath(".//display/publisher").first.text,
                                    :creation_date => r.xpath(".//display/creationdate").first.text,
                                    :volume => r.xpath(".//display/version").first.text
                                  }
                              }
    @page_results = WillPaginate::Collection.create(@page, @per_page, @total_results) do |pager|
      pager.replace(@records)
    end


    haml :search
  end
end

map "/sinatra" do  
  run MySinatra
end 


###
# Haml
###

## Haml to output unindented text

# CodeRay syntax highlighting in Haml
# First: gem install haml-coderay
# require 'haml-coderay'

# CoffeeScript filters in Haml
# First: gem install coffee-filter
# require 'coffee-filter'

# Automatic image dimensions on image_tag helper
# activate :automatic_image_sizes




###
# Page command
###

# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
# page "/path/to/file.html", :layout => :otherlayout
#
# A path which all have the same layout
# with_layout :admin do
#   page "/admin/*"
# end

# Proxy (fake) files
# page "/this-page-has-no-template.html", :proxy => "/template-file.html" do
#   @which_fake_page = "Rendering a fake page with a variable"
# end




###
# Helpers
###

# Methods defined in the helpers block are available in templates
# helpers do
#   def some_helper
#     "Helping"
#   end
# end





