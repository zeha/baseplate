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
      tpl.write config
      tpl.close
      logdir = tpl.path + '.d'
      FileUtils.mkdir logdir

      path = '/usr/lib/fai:' + ENV['PATH']
      cmd = "PATH=#{path} HOME=#{logdir} LOGDIR=#{logdir} disklist=$(/usr/lib/fai/disk-info | sort) setup-storage -X -f #{tpl.path}"
      puts "* Execute: #{cmd}"
      if !@opts[:dryrun]
        p = IO.popen(cmd)
        out = p.readlines
        p.close

        if $?.exitstatus != 0
          raise "fai-setup-storage failed with exitstatus #{$?.exitstatus}. Output:\n#{out}"
        end
      else
        puts "  Config:"
        puts config
        puts "EOF"
      end

    ensure
      tpl.unlink unless tpl.nil?
      FileUtils.rm_r logdir unless logdir.nil?
    end

    def install_debian
      #yield
    end
  end

  class StorageConfig
    def self.evaluate(&script)
      c = new
      c.instance_eval(&script)
      c.config << ''
      c.config.join("\n")
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
