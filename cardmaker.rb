#!/usr/bin/env ruby

require 'sinatra'
require 'json'
require 'RMagick'
require 'tempfile'
require 'uri'
require 'base64'
require 'zlib'

class CardMaker < Sinatra::Base

  before do
    if params[:data]
      @data = JSON.parse(Zlib::Inflate.inflate(Base64.decode64(params[:data])))
    elsif params[:text].is_a?(Array)
      @data = params[:text].zip(params[:card]).select { |pair| not (pair[0].nil? or pair[0].empty?) }
    else
      @data = { 'text' => params[:text], 'card' => params[:card] }
    end
  end

  helpers do
    def escape(str)
      str.gsub(/[^\-_.!~*'()a-zA-Z\d;\/:@=$,\[\]]/) { |m| "%#{m.ord.to_s(16)}" }
    end

    def card_query(data)
      "data=#{escape(Base64.encode64(Zlib::Deflate.deflate(data.to_json)).strip.gsub(/\s+/,''))}"
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

  get '/card' do
    content_type 'image/png'
    make_card(@data['text'],@data['card'])
  end

  get '/cards' do
    @card_width = params[:width] || 250
    @permalink = "cards?#{card_query(@data)}"
    erb :cards
  end

  post '/cards' do
    redirect "cards?#{card_query(@data)}"
  end
end