# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

class Module
  # This is a lazy-ass implementation of a
  # lazy non-caching DB field,
  # that exists only to let me avoid using Sequel's ORM.

  # Define getter for a lazy field. The getter requires
  # @dataset and @id instance to be defined vars to actually function.
  def lazy_dataset_field(column_name, id_field = :id)
    define_method(column_name) do
      @dataset.where(id_field => @id).select(column_name).first[column_name]
    end
  end
end

module Sequel
  class Database
    alias_method :old_dataset_method, :dataset

    def dataset(*args)
      # HACK: avoid instance variable not initialized warnings,
      # by setting missing variables in Database's default_dataset
      ds = old_dataset_method(*args)
      ds.instance_variable_set(:@columns, nil)
      ds.instance_variable_set(:@skip_symbol_cache, nil)
      ds.row_proc = nil
      ds
    end
  end
end

module SequelHelpers
  # Convenience/consistence wrapper to Sequel.connect(), with some workarounds
  def database_connect(*args, &block)
    db = Sequel.connect(*args, &block)
    # HACK: avoid "instance variable @transaction_mode not initialized" warning
    db.transaction_mode=nil
    db
  end

  # Performs required cleanup to avoid leaking database instances
  # upon plugin reloading, etc.
  def database_disconnect(database)
    database.disconnect
    Sequel.synchronize{::Sequel::DATABASES.delete(database)}
  end
end
