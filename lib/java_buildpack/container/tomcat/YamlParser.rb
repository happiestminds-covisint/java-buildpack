require 'yaml'
require 'pp'
require 'open-uri'
require 'rexml/document'
require 'java_buildpack/component/base_component'
require 'digest/sha1'

class MvnDownloadArtifact
  attr_reader :downloadUrl, :sha1, :artifactname, :username, :password, :contextpath
  def initialize(downloadUrl, sha1, artifactname, username, password, contextpath)
    # Instance variables
    @downloadUrl = downloadUrl
    @sha1 = sha1
    @artifactname = artifactname
    @username = username
    @password = password
    @contextpath = contextpath
  end
end

class YamlParser < JavaBuildpack::Component::BaseComponent
  
  SHA1 = 'artifact-resolution/data/sha1'
  REPOSITORY_PATH = 'artifact-resolution/data/repositoryPath'
  CONTEXT_PATH = 'context-path:'
  def initialize(context)
     super(context)
     @application.root.entries.find_all do |p|               
                           # load yaml file from app dir
                           if p.fnmatch?('*.yaml')
                             @config=YAML::load_file(File.join(@application.root.to_s, p.to_s))
                             
                             unless @config.nil? || @config == 0                      
                              @location =  @config["repository"]["location"]
                              @repoid =  @config["repository"]["repo-id"]
                              @username =  @config["repository"]["authentication"]["username"]
                              @password =  @config["repository"]["authentication"]["password"]
                              @resolveurl = "http://#{@location}/service/local/artifact/maven/resolve?"
                              @contenturl= "http://#{@location}/service/local/artifact/maven/content?"
                              @repopath = "&r=#{@repoid}"
                              @webapps = @config['webapps']
                              @libraries=@config['libraries']  
                              $configtomcat=@config["container"]["configtomcat"]
                              $configjdk=@config["container"]["configjdk"]
                              unless @libraries.nil?
                                @libraries.each do|lib|
                                    ['g', 'a', 'v'].each {|key| abort "Invalid YAML format in libraries" unless !lib.is_a?(String) && lib.has_key?(key)} 
                                end 
                              end
                              @webapps.each do |app|
                                ['g', 'a', 'v'].each {|key| abort "Invalid YAML format in webapps" unless !app.is_a?(String) && app.has_key?(key)}
                              end
                              end
                            end
            end  
           
  end
  
def detect
  end
        
  
  def compile
    unless @config.nil? || @config == 0
      libs=read_config "libraries", "jar"
      unless libs.nil?
        libs.each do |lib| 
          outputpath = @droplet.root + lib.artifactname
            open(lib.downloadUrl, http_basic_authentication: [lib.username, lib.password]) do 
                                  |file|
                    File.open(outputpath, "w") do |out|
                      out.write(file.read)
                    end 
                    checksum = Digest::SHA1.file(outputpath).hexdigest  
                    if checksum == lib.sha1
                          FileUtils.mkdir_p tomcat_lib
                          FileUtils.cp_r(outputpath, tomcat_lib)
                          else 
                          puts "check sum got failed for file: #{lib.downloadUrl}"
                          exit 1
                    end
            end 
       end 
     end
    end
  end
  
  def release
       end
  
  def read_config(component, type)
    @compMaps||= Array.new
    unless @config[component].nil?
    @config[component].each do |val|

    params = []
    %w( g a v ).each do |param| params.push(param + '=' + val[param].to_s) end 
    contextPath = params.join('&')
              
    begin
        #parse YAML and get the xml response
        contextPath+="#{@repopath}&p=#{type}"

        mvnXmlResponse=open(@resolveurl+contextPath, http_basic_authentication: ["#{@username}", "#{@password}"]).read
           rescue OpenURI::HTTPError => ex
            puts "wrong url endpoint: #{@resolveurl+contextPath}"
            abort
           end

      # create Object which is having downloadUrl, sha1 (for checksum) and version (for cache history)
      @compMaps << MvnDownloadArtifact.new(@contenturl+contextPath,
      REXML::Document.new(mvnXmlResponse).elements[SHA1].text,
      REXML::Document.new(mvnXmlResponse).elements[REPOSITORY_PATH].text.rpartition("/").last,
      @username,
      @password,
      val['context-path']
     )

    end
    end

    return @compMaps

  end

    # The Tomcat +lib+ directory
    #
    # @return [Pathname] the Tomcat +lib+ directory
    def tomcat_lib
      @droplet.sandbox + 'lib'
    end
end
