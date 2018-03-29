require 'omniauth-oauth2'
require 'rest_client'
require 'builder'
require 'nokogiri'
require 'multi_xml'

module OmniAuth
  module Strategies
    class Protech < OmniAuth::Strategies::OAuth2
      option :app_options, { app_event_id: nil }
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
        slug = request.params['slug']
        account = Account.find_by(slug: slug)
        @app_event = account.app_events.where(id: options.app_options.app_event_id).first_or_create(activity_type: 'sso')

        @token = request.params['Token']

        if @token.present?
          self.access_token = {
            token: @token,
            expires: Time.now.utc + 60.minutes
          }
          self.env['omniauth.auth'] = auth_hash
          self.env['omniauth.origin'] = '/' + slug
          self.env['omniauth.app_event_id'] = @app_event.id
          finalize_app_event
          call_app!
        else
          @app_event.logs.create(level: 'error', text: 'Token is absent in the request params')
          @app_event.fail!
          fail!(:invalid_credentials)
        end
      end

      def auth_hash
        hash = AuthHash.new(provider: name, uid: uid)
        hash.info = info
        hash.credentials = self.access_token
        hash
      end

      private

      def get_user_info
        request_log = "Protech Authentication Request:\nPOST #{user_info_url}"
        @app_event.logs.create(level: 'info', text: request_log)
        response = RestClient::Request.execute(request_options)
        response_log = "Protech Authentication Response (code: #{response&.code}):\n#{response.inspect}"
        if response.code == 200
          @app_event.logs.create(level: 'info', text: response_log)
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
          @app_event.logs.create(level: 'error', text: response_log)
          @app_event.fail!
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

      def request_options
        options = {
          method: :post,
          url: user_info_url,
          payload: user_info_payload,
          headers: request_headers
        }
        options[:proxy] = proxy_url if proxy_url
        options
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

      def finalize_app_event
        app_event_data = {
          user_info: {
            uid: info[:uid],
            first_name: info[:first_name],
            last_name: info[:last_name],
            email: info[:email],
            member_type: info[:member_type],
            is_member: info[:member]
          }
        }

        @app_event.update(raw_data: app_event_data)
      end
    end
  end
end
