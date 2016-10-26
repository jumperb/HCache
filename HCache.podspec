Pod::Spec.new do |s|

  s.name         = "HCache"
  s.version      = "1.2.3"
  s.summary      = "A short description of HCache."

  s.description  = <<-DESC
                   A longer description of HCache in Markdown format.

                   * Think: Why did you write this? What is the focus? What does it do?
                   * CocoaPods will be using this to generate tags, and improve search results.
                   * Try to keep it short, snappy and to the point.
                   * Finally, don't worry about the indent, CocoaPods strips it!
                   DESC

  s.homepage     = "https://github.com/jumperb/HCache"

  s.license      = "Copyright"
  
  s.author       = { "jumperb" => "zhangchutian_05@163.com" }

  s.source       = { :git => "https://github.com/jumperb/HCache.git", :tag => s.version.to_s}

  s.source_files  = 'Classes/**/*.{h,m}'
  
  s.requires_arc = true

  s.dependency 'Hodor'
  
  s.ios.deployment_target = '7.0'

end
