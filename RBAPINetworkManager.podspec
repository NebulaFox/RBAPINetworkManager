
Pod::Spec.new do |s|

  s.name         = "RBAPINetworkManager"
  s.version      = "0.0.2"
  s.summary      = "Making API calls simple"

  s.description  = <<-DESC
                   Making API calls simple
                   DESC

  s.homepage     = "https://github.com/NebulaFox/RBAPINetworkManager"

  s.license      = { :type => 'NCSA', :license => 'LICENSE.md' }
  
  s.author             = "Robbie Bykowski"
  s.social_media_url   = "http://twitter.com/NebulaFox"

  s.platform     = :ios, "7.0"

  s.source       = { :git => "https://github.com/NebulaFox/RBAPINetworkManager.git" }

  s.source_files  = "RBAPINetworkManager/*.{h,m}"
  s.public_header_files = "RBAPINetworkManager/RBAPINetworkManager.h"

  s.requires_arc = true

  s.dependency "AFNetworking", "~> 2.0"
  s.dependency "Sculptor", "~> 0.3.0"

end
