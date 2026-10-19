Pod::Spec.new do |s|
  s.name = 'AnkiArchive'
  s.version = '0.1.0'
  s.summary = 'LearnAlert on-device Anki package reader'
  s.homepage = 'https://github.com/ublake/LearnAlert'
  s.author = 'LearnAlert'
  s.license = { :type => 'Proprietary' }
  s.source = { :git => 'https://github.com/ublake/LearnAlert.git', :tag => s.version.to_s }
  s.ios.deployment_target = '16.0'
  s.swift_version = '5.0'
  s.source_files = 'Sources/AnkiArchive/*.swift'
  s.libraries = 'sqlite3'
  s.dependency 'ZIPFoundation', '0.9.20'
  s.dependency 'CZstd', '1.5.7'
end
