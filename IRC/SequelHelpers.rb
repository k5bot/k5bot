# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

require 'rubygems'
require 'bundler/setup'
require 'sequel'
Sequel.extension(:migration)

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

  def dataset_upsert(dataset, condition)
    update_vals = yield(true)
    insert_vals = nil
    3.times do
      affected = dataset.where(condition).update(update_vals)
      case affected
        when 1
          return # success
        when 0
          insert_vals ||= yield(false)
          affected = dataset.insert_conflict.insert(insert_vals)
          return affected if affected && affected > 0
        else
          raise "Invalid affected rows count: #{affected}"
      end
    end
    raise 'Exhausted upsert attempts'
  end
end
