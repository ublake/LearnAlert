Pod::Spec.new do |s|
  s.name = 'CZstd'
  s.version = '1.5.7'
  s.summary = 'Zstandard decompression-only reader used by AnkiArchive'
  s.homepage = 'https://github.com/facebook/zstd'
  s.author = 'Zstandard contributors'
  s.license = { :type => 'BSD', :file => 'ZSTD-LICENSE' }
  s.source = { :git => 'https://github.com/ublake/LearnAlert.git', :tag => s.version.to_s }
  s.ios.deployment_target = '16.0'
  s.source_files = 'Sources/CZstd/zstddeclib.c', 'Sources/CZstd/include/*.h'
  s.public_header_files = 'Sources/CZstd/include/*.h'
  s.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) ZSTD_DISABLE_ASM=1' }
end
