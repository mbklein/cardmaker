#!/usr/bin/env ruby

require 'sinatra'
require 'json'
require 'RMagick'
require 'tempfile'
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
      text_size = 60
      color = source_card =~ /White/ ? 'black' : 'white'

      capfile = File.join(Dir.tmpdir, Dir::Tmpname.make_tmpname(['caption','.png'],nil))
      args = [
        'convert', '-background', 'transparent',  '-size', '600x600', 
        '-pointsize', text_size.to_s, '-fill', color.to_s, 
        '-interline-spacing', (text_size/3).to_s,
        '-font', 'Helvetica-Bold',
        "caption:#{text}", capfile
      ]
      Kernel.system(*args)
      cap = Magick::Image.read(capfile).first

      img = Magick::Image.read("cards/CAH_#{source_card}.png").first
      img.x_resolution = img.y_resolution = 300
      img.composite!(cap, 75, 75, Magick::OverCompositeOp)
      img.to_blob
    end
  end

  get '/' do
    erb :index
  end

  get '/card/*.png' do
    decode_params
    content_type 'image/png'
    make_card(@data['text'],@data['card'])
  end

  get '/cards/*' do
    decode_params
    erb :cards
  end

  post '/cards' do
    decode_params
    redirect permalink
  end
end