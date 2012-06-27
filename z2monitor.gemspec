Gem::Specification.new do |s|
  s.name        = 'z2monitor'
  s.version     = '1.0.1'
  s.date        = '2012-06-26'
  s.summary     = 'Zabbix CLI dashboard'
  s.description = 'A command line interface for viewing alerts from a Zabbix instance (for Zabbix 2.0)'
  s.authors     = ['Musee Ullah']
  s.email       = 'milkteafuzz@gmail.com'
  s.files       = Dir['lib/**/*.rb']
  s.executables = ['z2monitor']
  s.homepage    = 'https://github.com/liliff/z2monitor'
  s.requirements = ['json']
  s.add_runtime_dependency 'colored'
end
