class BpoweskiMongodbSearchCommunity < Formula
  desc "Search indexes and search management utilities for MongoDB"
  homepage "https://www.mongodb.com/"
  url "https://downloads.mongodb.org/mongodb-search-community/0.53.1/mongot_community_0.53.1_linux_aarch64.tgz"
  sha256 "6811ce118b8cc3b3f53774d7eeea0c035b43c2931d75699124514b32ddbdca73"
  license ""

  depends_on "mongodb-community"
  depends_on "openjdk"

  def install
    bin.install "mongot"
    bin.install "bin/mongot_community_deploy.jar"
    prefix.install "config.default.yml"
    prefix.install "mongot.example.logrotate"
    prefix.install "README.md"
    prefix.install "VERSION.txt"
    prefix.install "lib"
    prefix.install "LICENSE"
  end

  def mongot_conf
    <<~EOS
      syncSource:
        replicaSet:
          hostAndPort: "localhost:27017"
          tls: false
      storage:
        dataPath: "#{var}/lib/mongot"
      server:
        grpc:
          address: "localhost:27028"
          tls:
            mode: "disabled"
      metrics:
        enabled: true
        address: "localhost:9946"
      healthCheck:
        address: "localhost:8080"
      logging:
        verbosity: INFO
    EOS
  end

  def post_install
    (var/"lib/mongot").mkpath
    (var/"log/mongot").mkpath
    (etc/"mongot.yml").write mongot_conf unless File.exist?(etc/"mongot.yml")
  end

  service do
    run [opt_bin/"mongot", "--config", etc/"mongot.yml"]
    keep_alive true
    working_dir var/"lib/mongot"
    log_path var/"log/mongot/mongot.log"
    error_log_path var/"log/mongot/mongot.error.log"
    environment_variables PATH: std_service_path_env
  end

  test do
    system "#{bin}/mongot", "--version"
  end
end
