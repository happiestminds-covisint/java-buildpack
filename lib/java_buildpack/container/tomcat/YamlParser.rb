require 'yaml'
require 'pp'
require 'open-uri'
require 'rexml/document'
require 'java_buildpack/component/base_component'
require 'digest/sha1'

class MvnDownloadArtifact
  attr_reader :downloadUrl, :sha1, :version, :artifactname, :username, :password, :contextpath
  def initialize(downloadUrl, sha1, version, artifactname, username, password, contextpath)
    # Instance variables
    @downloadUrl = downloadUrl
    @sha1 = sha1
    @version = version
    @artifactname = artifactname
    @username = username
    @password = password
    @contextpath = contextpath
  end
end

class YamlParser < JavaBuildpack::Component::BaseComponent
  
  SHA1 = 'artifact-resolution/data/sha1'
  REPOSITORY_PATH = 'artifact-resolution/data/repositoryPath'
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
                              end
                            end
            end  
           
  end
  
def detect
  end
        
  
  def compile
    unless @config.nil? || @config == 0
      libs=read_config "libraries", "jar"
      libs.each do |lib| 
        #download_jar lib.version.to_s, lib.downloadUrl.to_s, lib.artifactname.to_s, tomcat_lib
        outputpath = @droplet.sandbox + lib.artifactname
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
  def release
       end
  
  def read_config(component, type)
    @compMaps||= Array.new
    @config[component].each do |val|

      begin
        #eliminate context path from component value
        contextpath =val.split(/\s/)[-1]
        if contextpath.include? "c:" 
           #remove the context path key and value from val
            puts "context path found..... removing it from parameters"
            puts val.slice!(" #{contextpath}")
        end  
        #parse YAML and get the xml response
        contextPath = val.gsub(/\s/,"&").gsub(":","=")+"#{@repopath}&p=#{type}"

        mvnXmlResponse=open(@resolveurl+contextPath, http_basic_authentication: ["#{@username}", "#{@password}"]).read
      rescue OpenURI::HTTPError => ex
        puts "wrong url endpoint: #{@resolveurl+contextPath}"
        abort
      end

      #from the mvn artifact xml response consrtuct final downloadable URL
      downloadUrl = "#{@contenturl}#{contextPath}"

      # create Object which is having downloadUrl, sha1 (for checksum) and version (for cache history)
      @compMaps << MvnDownloadArtifact.new(downloadUrl,
       REXML::Document.new(mvnXmlResponse).elements[SHA1].text,
      val.gsub(/\s/,"&").gsub(":","=").rpartition("=").last, 
      REXML::Document.new(mvnXmlResponse).elements[REPOSITORY_PATH].text.rpartition("/").last,
     @username,
     @password,
     contextpath
     )

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
