require 'baseplate/support'
require 'tempfile'
module Baseplate
  class Recipe
    attr_accessor :opts

    def self.run(filename, opts)
      r = new
      r.opts.merge!(opts)
      r.instance_eval(File.read(filename), filename)
    end

    def initialize
      @opts = {}
    end

    def recipe
      yield
    end

    def setup_storage(&script)
      config = StorageConfig.evaluate(&script)

      tpl = Tempfile.new('setupstorage')
      tpl.write config.join("\n")
      tpl.close

      path = '/usr/lib/fai:' + ENV['PATH']
      cmd = "PATH=#{path} disklist=$(/usr/lib/fai/disk-info | sort) setup-storage -X -f #{tpl.path}"
      if @opts[:dryrun]
        puts "Would execute: #{cmd}"
        puts "  Config:"
        puts config
        puts "EOF"
      else
        p = IO.popen(cmd)
        out = p.readlines
        p.close

        if $?.returncode != 0
          raise "fai-setup-storage failed with returncode #{$?.returncode}. Output:\n#{out}"
        end
      end

    ensure
      tpl.unlink if tpl
    end

    def install_debian
      #yield
    end
  end

  class StorageConfig
    def self.evaluate(&script)
      c = new
      c.instance_eval(&script)
      c.config
    end

    attr_reader :config

    def initialize
      @config = []
    end

    def disk(name)
      @config << 'disk_config %s' % name.to_s
    end

    def primary(mountpoint, fstype, size, options = nil)
      if fstype.to_s == "swap"
        options ||= "sw"
      else
        options ||= "rw"
      end
      @config << 'primary %s %s %s %s' % [mountpoint, size, fstype, options]
    end
  end
end
