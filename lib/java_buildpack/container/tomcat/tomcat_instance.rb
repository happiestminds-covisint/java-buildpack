# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/util/tokenized_version'
require 'java_buildpack/container/tomcat/YamlParser'
require 'open-uri'
require 'pathname'
require 'digest/sha1'
require 'json'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for the Tomcat instance.
    class TomcatInstance < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Container

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context) { |candidate_version| candidate_version.check_size(3) }
        @yamlobj=YamlParser.new(context)
       end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
         download(@version, @uri) { |file| expand file }
          if isYaml?
               wars = []
               contextpaths = Hash.new
               wapps=@yamlobj.read_config "webapps", "war"
                     wapps.each do |wapp|
                        unless wapp.contextpath.nil?
                            wapp.contextpath.strip!
                            warFilename = (wapp.contextpath == "/") ? "/ROOT" : wapp.contextpath
                            warFilename.slice! "/"
                        end
                        warFilename =  warFilename.nil? ?  wapp.artifactname : "#{warFilename}.war"
                        outputpath = @droplet.root + warFilename
                        #if only contextpath available in YAML will be selected for Context tag entry in server.xml
                        unless wapp.contextpath.nil? 
                        wapp.artifactname.slice!(".war")
                        contextpaths[wapp.artifactname]=wapp.contextpath
                        end
                        #file download from url with http_header authentication
                        open(wapp.downloadUrl, http_basic_authentication: [wapp.username, wapp.password]) do 
                        |file|
                               File.open(outputpath, "w") do |out|
                               out.write(file.read)
                              end
                              checksum = Digest::SHA1.file(outputpath).hexdigest
                              if checksum == wapp.sha1
                                 wars.push Pathname.new(outputpath)
                               else
                                 puts "Downloaded check sum #{checksum} got failed for file: #{war.downloadUrl} of repository check sum : #{wapp.sha1}"
                                 exit 1
                               end
                        end
          end
        FileUtils.mkdir_p tomcat_webapps
        link_webapps(wars, tomcat_webapps)
        #dyanamic context tag will be created under Server.xml 
        # Commenting this out temporarily. Till a better solution is found
        #unless contextpaths.nil?
        #context_path_appender contextpaths
        #end
        else
         
          link_webapps(@application.root.children, tomcat_webapps)
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      private

      TOMCAT_8 = JavaBuildpack::Util::TokenizedVersion.new('8.0.0').freeze

      private_constant :TOMCAT_8

      def configure_jasper
        return unless @version < TOMCAT_8

        document = read_xml server_xml
        server   = REXML::XPath.match(document, '/Server').first

        listener = REXML::Element.new('Listener')
        listener.add_attribute 'className', 'org.apache.catalina.core.JasperListener'

        server.insert_before '//Service', listener

        write_xml server_xml, document
      end

      def configure_linking
        document = read_xml context_xml
        context  = REXML::XPath.match(document, '/Context').first

        if @version < TOMCAT_8
          context.add_attribute 'allowLinking', true
        else
          context.add_element 'Resources', 'allowLinking' => true
        end

        write_xml context_xml, document
      end

      def expand(file)
        with_timing "Expanding Tomcat to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          FileUtils.mkdir_p @droplet.sandbox
          shell "tar xzf #{file.path} -C #{@droplet.sandbox} --strip 1 --exclude webapps 2>&1"

          @droplet.copy_resources
          configure_linking
          configure_jasper
          if ENV.has_key?('valve')
          unless ENV['valve'].nil? && ENV['valve'].empty?
          valve_appender
          end
          end
        end
      end

      def root
        tomcat_webapps + 'ROOT'
      end

      def tomcat_datasource_jar
        tomcat_lib + 'tomcat-jdbc.jar'
      end

      def web_inf_lib
        @droplet.root + 'WEB-INF/lib'
      end

      def link_webapps(from, to)
        webapps = []
        webapps.push(from.find_all {|p| p.fnmatch('*.war')})

        # Explode zips
        # TODO: Need to figure out a way to add 'rubyzip' gem to the image
        #       and avoid shelling out to "unzip".
        zips = from.find_all {|p| p.fnmatch('*.zip')}
        zips.each do |zip|
          IO.popen(['unzip', '-o', '-d', @application.root.to_s, zip.to_s, '*.war']) do |io|
            io.readlines.each do |line|
              line.gsub!(/\s*$/, '')
              next unless line.chomp =~ /\.war$/
              war = line.split()[-1]
              webapps.push(Pathname.new(@application.root.to_s) + war)
            end
          end
        end
        webapps.flatten!

        if (not webapps.empty?)
          link_to(webapps, to)
        else
          link_to(from, root)
          @droplet.additional_libraries << tomcat_datasource_jar if tomcat_datasource_jar.exist?
          @droplet.additional_libraries.link_to web_inf_lib
        end
      end
      def isYaml?
                 @application.root.entries.find_all do |p|
                   if p.fnmatch?('*.yaml')
                          return true
                   end  
                   
               end  
               return false
         end
      #using REXML we are adding Context Elements under Host tag in server.xml   
      def context_path_appender(contextpaths)
           document = read_xml server_xml
           host   = REXML::XPath.match(document, '/Server/Service/Engine/Host').first
           
            contextpaths.each do | artifactname,contextpath|
              context = REXML::Element.new('Context')
              context.add_attribute 'docBase', artifactname
              context.add_attribute 'reloadable', 'true'
              context.add_attribute 'path', contextpath
              host.elements.add(context)
            end
                    
           write_xml server_xml, document
         end 
       #using REXML we are adding Valve Elements under Host Context and Engine tag in server.xml 
       def valve_appender
          valveclass= ENV['valve']
          begin
           obj=JSON.parse(valveclass)
          rescue JSON::ParserError => e
           puts "NOT A VALID JSON FORMAT"
           return false
          end
          document = read_xml server_xml
          documentcon = read_xml context_xml
          context  = REXML::XPath.match(documentcon, '/Context').first
          engine= REXML::XPath.match(document, '/Server/Service/Engine').first
          host   = REXML::XPath.match(document, '/Server/Service/Engine/Host').first
          obj.each do |k,a|
             if obj.has_key?(k)	
               for i in 0..obj[k].length-1
                 valve = REXML::Element.new('Valve') 
                 obj[k][i].each do |attribute,value|
                  valve.add_attribute  attribute, value 
                 end 
                 if  k == 'host'
                   host.elements.add(valve)
                 elsif k == 'context'
                   context.elements.add(valve)
                 elsif k == 'engine'
                   engine.insert_before '//Host', valve
                 end 
               end
             end
            end 
          write_xml server_xml, document
          write_xml context_xml,documentcon
       end
    end
  end
end
