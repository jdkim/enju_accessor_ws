#!/usr/bin/env ruby
require 'sinatra'
require 'json'
require 'enju_accessor'

configure do
	set :enju, EnjuAccessor.new("http://localhost:38401/cgi-lilfes/enju")
	set :mogura, EnjuAccessor.new("http://localhost:38401/cgi-lilfes/enju")
	set :enju_gtrec, EnjuAccessor.new("http://localhost:38401/cgi-lilfes/enju")
	set :mogura_gtrec, EnjuAccessor.new("http://localhost:38401/cgi-lilfes/enju")
end

before do
	if request.content_type
		body = request.body.read

		if request.content_type.downcase =~ /application\/json/
			begin
				json_params = JSON.parse body, :symbolize_names => true unless body.empty?
			rescue => e
				@error_message = 'ill-formed JSON string'
			end
			params.merge!(json_params) unless json_params.nil?
		elsif request.content_type.downcase =~ /text\/plain/
			params.merge!({text:body})
		end
	end
end

get '/' do
	unless params[:text].nil?
		@annotations = get_annotations
	end
	erb :index
end

post '/' do
	begin
		raise ArgumentError, @error_message if @error_message

		text = params[:text]
		raise ArgumentError, "'text' value needs to be supplied." if text.nil?

		annotations = get_annotations

		headers \
			'Content-Type' => 'application/json'
		body annotations.to_json

	rescue ArgumentError => e
		headers \
			'Content-Type' => 'application/json'
		status 400
		{message:e.message}.to_json

	rescue IOError => e
		headers \
			'Content-Type' => 'application/json'
		status 502
		{message:e.message}.to_json
	end
end

def get_annotations
	text = params[:text]

	mode = params[:mode]
	model = params[:model]
	parser = params[:parser]

	cgi = if model == 'GTREC'
		parser == 'Mogura' ? settings.mogura_gtrec : settings.enju_gtrec
	else # default: 'GENIA'
		parser == 'Mogura' ? settings.mogura : settings.enju
	end

	params[:mode] == 'POS' ? cgi.tag_text(text) : cgi.parse_text(text)
end
