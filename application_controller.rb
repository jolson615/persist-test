require 'bundler'
Bundler.require
require_relative 'models/message.rb'

class MyApp < Sinatra::Base

  get '/' do
    erb :index
  end

  post '/board' do
    @new_message = Message.new(params[:name],params[:content])
    erb :board
  end

  post '/results' do
    print params[:data]
    @processed_data = Analysis.new(params[:data])
    erb :results
  end

  get '/results' do
    erb :results
  end

end
