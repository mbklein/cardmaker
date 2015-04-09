#!/usr/bin/env ruby

require 'sinatra'
require 'cahdmaker'
require 'json'
require 'uri'
require 'base64'
require 'zlib'

class CardMaker < Sinatra::Base

  helpers do
    def decode_params
      data = params[:data] || (params[:splat] ? params[:splat].join('/') : nil)
      if data
        @data = decode_data(data)
      elsif params[:text].is_a?(Array)
        @data = params[:text].collect.with_index { |text,index|
          { 'text' => text, 'card' => (params[:card][index] || 'White') }
        }
      else
        @data = { 'text' => params[:text], 'card' => params[:card] }
      end
      @card_width = params[:width] || 250
    end

    def escape(str)
      str.gsub(/[^\-_.!~*'()a-zA-Z\d;\/:@=$,\[\]]/) { |m| "%#{m.ord.to_s(16)}" }
    end

    def decode_data(data)
      JSON.parse(Zlib::Inflate.inflate(Base64.decode64(data)))
    end

    def encode_data(data)
      escape(Base64.encode64(Zlib::Deflate.deflate(data.to_json)).strip.gsub(/\s+/,''))
    end

    def permalink
      "/cards/#{encode_data(@data)}"
    end

    def make_card(text, source_card)
      maker = Cahdmaker::Maker.new
      maker.send(source_card.downcase.to_sym, text).to_blob
    end
  end

  get '/' do
    erb :index, :layout => :layout
  end

  get '/card/*.png' do
    decode_params
    content_type 'image/png'
    make_card(@data['text'],@data['card'])
  end

  get '/cards/*' do
    decode_params
    erb :cards, :layout => :layout
  end

  get '/cards' do
    decode_params
    erb :cards, :layout => :layout
  end

  post '/cards' do
    decode_params
    erb :cards, :layout => :layout
  end
end
