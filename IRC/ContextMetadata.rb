# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Thread-safe context metadata holder

class ContextMetadata
  THREAD_LOCAL_KEY = :context_metadata

  def self.run_with(values_hash)
    backup = Thread.current[THREAD_LOCAL_KEY]
    if values_hash
      new_hash = (backup || {}).merge(values_hash)
      Thread.current[THREAD_LOCAL_KEY] = new_hash
    end
    begin
      yield
    ensure
      Thread.current[THREAD_LOCAL_KEY] = backup
    end
  end

  def self.get
    Thread.current[THREAD_LOCAL_KEY]
  end

  def self.get_key(key)
    (Thread.current[THREAD_LOCAL_KEY] || {})[key.to_sym]
  end
end
