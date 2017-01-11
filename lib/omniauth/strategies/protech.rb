require 'omniauth-oauth2'
require 'rest_client'
require 'builder'
require 'nokogiri'
require 'multi_xml'

module OmniAuth
  module Strategies
    class Protech < OmniAuth::Strategies::OAuth2
      option :name, 'protech'
      option :client_options, {
        authentication_url: 'MUST BE SET',
        security_password: 'MUST BE SET',
        user_info_url: 'MUST BE SET',
        soap_namespace: 'MUST BE SET',
        proxy_url: nil,
        slug: 'MUST BE SET'
      }

      uid { raw_info['number'] }

      info do
        {
          first_name: raw_info['first_name'],
          last_name: raw_info['last_name'],
          email: raw_info['email'],
          member_type: raw_info['member_type'],
          member: raw_info['member'],
          uid: raw_info['number'],
          token: @token
        }
      end

      def raw_info
        @raw_info ||= get_user_info
      end

      def request_phase
        redirect sign_in_url + "?returnURL=" + URI.encode(callback_url + "?slug=#{slug}&token=")
      end

      def callback_phase
        self.access_token = {
          token: request.params['Token'],
          expires: Time.now.utc + 60.minutes
        }
        @token = request.params['Token']
        self.env['omniauth.auth'] = auth_hash
        self.env['omniauth.origin'] = '/' + request.params['slug']
        call_app!
      end

      def auth_hash
        hash = AuthHash.new(provider: name, uid: uid)
        hash.info = info
        hash.credentials = self.access_token
        hash
      end

      private

      def get_user_info
        RestClient.proxy = proxy_url if proxy_url
        response = RestClient.post user_info_url, user_info_payload, request_headers
        if response.code == 200
          body = response.body
          body.gsub!('&gt;', '>')
          body.gsub!('&lt;', '<')
          body.gsub!('<?xml version="1.0" encoding="UTF-16"?>', '')
          doc = {}
          MultiXml.parser = :nokogiri
          xml_doc = MultiXml.parse(body, symbolize_keys: true)[:Envelope][:Body][:AuthenticateTokenResponse][:AuthenticateTokenResult][:iBridge][:User]
          xml_doc.each { |k, v| doc[k.to_s.downcase] = v }
          doc[:uid] = doc[:number]
          doc
        else
          {}
        end
      end

      def user_info_payload
        builder = ::Builder::XmlMarkup.new; false
        builder.instruct! :xml, version: '1.0', encoding: 'utf-8'
        builder.soap :Envelope, namespaces do
          builder.soap :Header
          builder.soap :Body do
            builder.aut :AuthenticateToken do
              builder.aut(:securityPassword) { builder.text!(security_password) }
              builder.aut(:token) { builder.text!(@token) }
            end
          end
        end
        builder.target!
      end

      def user_info_url
        options.client_options.user_info_url
      end

      def soap_namespace
        options.client_options.soap_namespace
      end

      def namespaces
        {
          'xmlns:soap' => 'http://www.w3.org/2003/05/soap-envelope',
          'xmlns:aut' => soap_namespace
        }
      end

      def request_headers
        {
          'Content-Type' => 'text/xml; charset=utf-8'
        }
      end

      def security_password
        options.client_options.security_password
      end

      def sign_in_url
        options.client_options.authentication_url
      end

      def slug
        options.client_options.slug
      end

      def proxy_url
        options.client_options.proxy_url
      end

      def xpath_path
        '//Envelope/Body/AuthenticateTokenResponse/AuthenticateTokenResult'
      end

    end
  end
end
