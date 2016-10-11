require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/module/delegation'

module BigqueryBackwardCompatibilityTable
  class Migrator
    class Error < StandardError
    end

    class IllegalMigrationNameError < Error
      def initialize(name = nil)
        if name
          super("Illegal name for migration file: #{name}\n\t(only lower case letters, numbers, and '_' allowed).")
        else
          super("Illegal name for migration.")
        end
      end
    end

    MigrationFilenameRegexp = /\A([0-9]+)_([_a-z0-9]*)\.?([_a-z0-9]*)?\.rb\z/

    attr_reader :paths

    def initialize(paths)
      @paths = Array(paths)
    end

    def migrate
      p migrations(paths)
    end

    def migrations(paths)
      files ||= Dir[*paths.map { |p| "#{p}/**/[0-9]*_*.rb" }] 

      migrations = files.map do |file|
        version, name, scope = parse_migration_filename(file)
        raise IllegalMigrationNameError.new(file) unless version
        version = version.to_i
        name = name.camelize

        Migration.load(name, version, file, scope)
        # puts "name: #{name}, version: #{version}, file: #{file}, scope: #{scope}"
      end

      migrations.sort_by(&:version)
    end

    def parse_migration_filename(filename) # :nodoc:
      File.basename(filename).scan(MigrationFilenameRegexp).first
    end

    class << self
      def run
        paths = ['bq/migrate']
        self.new(paths).migrate
      end
    end
  end

  class Migration < Struct.new(:name, :version, :filename, :scope)
    def basename
      File.basename(filename)
    end

    def mtime
      File.mtime filename
    end

    delegate :migrate, :announce, :write, :disable_ddl_transaction, to: :migration

    private

    attr_reader :migration

    class << self
      def load(name, version, filename, scope)
        require(File.expand_path(filename))
        name.constantize.new(name, version, filename, scope)
      end
    end
  end
end