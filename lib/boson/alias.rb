require 'alias'

module Boson
  class Manager
    # hack
    def self.during_create_commands(lib, commands)
      AliasLib.create_command_aliases(lib, commands) if commands.size > 0 && !lib.no_alias_creation
    end
  end

  class Command
    # hack
    alias_method :_file_string_and_method_for_args, :file_string_and_method_for_args

    def file_string_and_method_for_args(lib)
      if !lib.is_a?(ModuleLibrary) && (klass_method = (lib.class_commands || {})[@name])
        klass, meth = klass_method.split(NAMESPACE, 2)
        if (meth_locations = MethodInspector.find_method_locations_for_19(klass, meth))
          file_string = File.read meth_locations[0]
        end
      else
        file_string, meth = _file_string_and_method_for_args(lib)
      end
      [file_string, meth]
    end
  end

  class Library
    # [*:no_alias_creation*] Boolean which doesn't create aliases for a library. Useful for libraries that configure command
    #                        aliases outside of Boson's control. Default is false.
    attr_reader :no_alias_creation
    # [*:class_commands*] A hash of commands to create. A hash key-pair can map command names to any string of ruby code
    #                     that ends with a method call. Or a key-pair can map a class to an array of its class methods
    #                     to create commands of the same name. Example:
    #                      :class_commands=>{'spy'=>'Bond.spy', 'create'=>'Alias.manager.create',
    #                       'Boson::Util'=>['detect', 'any_const_get']}
    attr_reader :class_commands

    def _initialize_library_module
      AliasLib.create_class_aliases(@module, @class_commands) unless
        @class_commands.nil? || @class_commands.empty? || @method_conflict
      super
    end

    def additions_or_namespace?
      @module || @class_commands
    end
  end

  module AliasLib
    class << self
      def create_class_aliases(mod, class_commands)
        class_commands.dup.each {|k,v|
          if v.is_a?(Array)
            class_commands.delete(k).each {|e| class_commands[e] = "#{k}.#{e}"}
          end
        }
        Alias.manager.create_aliases(:any_to_instance_method, mod.to_s=>class_commands.invert)
      end

      def create_command_aliases(lib, commands)
        lib.module ? prep_and_create_instance_aliases(commands, lib.module) : check_for_uncreated_aliases(lib, commands)
      end

      def prep_and_create_instance_aliases(commands, lib_module)
        aliases_hash = {}
        select_commands = Boson.commands.select {|e| commands.include?(e.name)}
        select_commands.each do |e|
          if e.alias
            aliases_hash[lib_module.to_s] ||= {}
            aliases_hash[lib_module.to_s][e.name] = e.alias
          end
        end
        create_instance_aliases(aliases_hash)
      end

      def create_instance_aliases(aliases_hash)
        Alias.manager.create_aliases(:instance_method, aliases_hash)
      end

      def check_for_uncreated_aliases(lib, commands)
        return if lib.is_a?(GemLibrary)
        if (found_commands = Boson.commands.select {|e| commands.include?(e.name)}) && found_commands.find {|e| e.alias }
          $stderr.puts "No aliases created for library #{lib.name} because it has no module"
        end
      end

    end
  end
end
