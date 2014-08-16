class Hiera
  module Backend
    class Module_data_backend
      def initialize(cache=nil)
        require 'yaml'
        require 'hiera/filecache'

        Hiera.debug("Hiera Module Data backend starting")

        @cache = cache || Filecache.new
      end

      def load_module_config(module_name, environment)
        default_config = {:hierarchy => ["common"]}

        mod = Puppet::Module.find(module_name, environment)

        return default_config unless mod

        path = mod.path
        module_config = File.join(path, "data", "hiera.yaml")
        config = {}

        if File.exist?(module_config)
          Hiera.debug("Reading config from %s file" % module_config)
          config = load_data(module_config)
        end
        
        config["path"] = path

        default_config.merge(config)
      end

      def load_data(path)
        return {} unless File.exist?(path)

        @cache.read(path, Hash, {}) do |data|
          YAML.load(data)
        end
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up %s in Module Data backend" % key)

        module_name = begin
          scope["module_name"]
        rescue Puppet::ParseError # Gets thrown if not in a module and strict_variables = true
        end

        unless module_name
          Hiera.debug("Skipping Module Data backend as this does not look like a module")
          return answer
        end

        config = load_module_config(scope["module_name"], scope["::environment"])
        unless config["path"]
          Hiera.debug("Could not find a path to the module '%s' in environment '%s'" % [scope["module_name"], scope["::environment"]])
          return answer
        end

        config[:hierarchy].each do |source|
          source = File.join(config["path"], "data", "%s.yaml" % Backend.parse_string(source, scope))

          Hiera.debug("Looking for data in source %s" % source)
          data = load_data(source)

          raise("Data loaded from %s should be a hash but got %s" % [source, data.class]) unless data.is_a?(Hash)

          next if data.empty?
          next unless data.include?(key)

          new_answer = Backend.parse_answer(data[key], scope)
          case resolution_type
            when :array
              raise("Hiera type mismatch: expected Array and got %s" % new_answer.class) unless (new_answer.kind_of?(Array) || new_answer.kind_of?(String))
              answer ||= []
              answer << new_answer

            when :hash
              raise("Hiera type mismatch: expected Hash and got %s" % new_answer.class) unless new_answer.kind_of?(Hash)
              answer = Backend.merge_answer(new_answer, answer)
            else
              answer = new_answer
              break
          end
        end

        return answer
      end
    end
  end
end
