class BpoweskiMongodbSearchCommunity < Formula
  desc "Search indexes and search management utilities for MongoDB"
  homepage "https://www.mongodb.com/"
  url "https://downloads.mongodb.org/mongodb-search-community/0.53.1/mongot_community_0.53.1_linux_aarch64.tgz"
  sha256 "6811ce118b8cc3b3f53774d7eeea0c035b43c2931d75699124514b32ddbdca73"
  license ""

  depends_on "mongodb-community"
  depends_on "openjdk@21"

  def install
    # Patch the mongot script to use Homebrew's OpenJDK instead of bundled JDK
    inreplace "mongot" do |s|
      # Replace the DIR variable and JAVA_HOME setup
      s.gsub!('DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"', '')
      s.gsub!(/if \[\[ \$OSTYPE == "darwin"\* \]\]; then\n  export JAVA_HOME="\$\{DIR\}\/bin\/jdk\/Contents\/Home"\nelse\n  export JAVA_HOME="\$\{DIR\}\/bin\/jdk"\nfi/,
              "export JAVA_HOME=\"#{Formula["openjdk@21"].opt_prefix}/libexec/openjdk.jdk/Contents/Home\"")
      # Update classpath to use absolute paths
      s.gsub!('-cp "${DIR}/lib/*:${DIR}/bin/mongot_community_deploy.jar"',
              "-cp \"#{prefix}/lib/*:#{bin}/mongot_community_deploy.jar\"")
    end

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
          username: mongotUser
          passwordFile: "#{etc}/mongot/passwordFile"
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
    (etc/"mongot").mkpath

    # Create password file with restricted permissions
    password_file = etc/"mongot/passwordFile"
    unless password_file.exist?
      password_file.write("mongotUser")
      password_file.chmod(0600)  # Owner read/write only
    end

    (etc/"mongot.yml").write mongot_conf unless File.exist?(etc/"mongot.yml")

    # Print setup instructions
    ohai "MongoDB User Setup Required"
    puts <<~EOS
      Before starting mongot, you need to create the mongotUser in MongoDB:

      1. Connect to your MongoDB instance:
         mongosh --port 27017

      2. Create the mongotUser in the admin database:
         use admin
         db.createUser({
           user: "mongotUser",
           pwd: "mongotUser",
           roles: [
             { role: "readAnyDatabase", db: "admin" },
             { role: "clusterMonitor", db: "admin" }
           ]
         })

      3. Update the password in #{etc}/mongot/passwordFile if desired

      4. Start mongot:
         brew services start #{name}
    EOS
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
