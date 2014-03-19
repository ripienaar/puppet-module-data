class Hiera
  module Backend
    class Module_data_backend
      def initialize(cache=nil)
        require 'yaml'
        require 'json'
        require 'hiera/filecache'

        Hiera.debug("Hiera Module Data backend starting")

        @cache = cache || Filecache.new
      end

      def load_module_config(module_name, environment)
        default_config = {:hierarchy => ["common"], :backends => ["yaml"]}

        if mod = Puppet::Module.find(module_name, environment)
          path = mod.path
          module_config = File.join(path, "data", "hiera.yaml")
          config = {}

          if File.exist?(module_config)
            Hiera.debug("Reading config from %s file" % module_config)
            config = load_data(module_config)
          end

          config["path"] = path

          return default_config.merge(config)
        else
          return default_config
        end
      end

      def load_data(path, backend="yaml")
        return {} unless File.exist?(path)

        @cache.read(path, Hash, {}) do |data|
          case backend
            when "yaml"
              YAML.load(data)
            when "json"
              JSON.parse(data)
            else
              Hiera.debug("Could not parse data as the backend '%s' is not implemented yet" % backend)
              return {}
          end
        end
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up %s in Module Data backend" % key)

        unless scope["module_name"]
          Hiera.debug("Skipping Module Data backend as this does not look like a module")
          return answer
        end

        config = load_module_config(scope["module_name"], scope["environment"])

        unless config["path"]
          Hiera.debug("Could not find a path to the module '%s' in environment '%s'" % [scope["module_name"], scope["environment"]])
          return answer
        end

        catch (:found_answer) do
          config[:backends].each do |backend|
            config[:hierarchy].each do |source|
              source = File.join(config["path"], "data", "%s.%s" % [Backend.parse_string(source, scope), backend])

              Hiera.debug("Looking for data in source %s" % source)
              data = load_data(source, backend)

              raise("Data loaded from %s should be a hash but got %s" % [source, data.class]) unless data.is_a?(Hash)

              next if data.empty?
              next unless data.include?(key)

              found = data[key]

              case resolution_type
                when :array
                  raise("Hiera type mismatch: expected Array or String and got %s" % found.class) unless [Array, String].include?(found.class)
                  answer ||= []
                  answer << Backend.parse_answer(found, scope)

                when :hash
                  raise("Hiera type mismatch: expected Hash and got %s" % found.class) unless found.is_a?(Hash)
                  answer = Backend.parse_answer(found, scope).merge(answer || {})
                else
                  answer = Backend.parse_answer(found, scope)
                  throw :found_answer
              end
            end
          end
        end

        return answer
      end
    end
  end
end
