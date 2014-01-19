require 'fileutils'
module TestHelpers

  def wait_for_lock(mutex)
    ensure_path_to_mutex(mutex)
    total_wait_time = 0.0
    while File.exists?(mutex_path(mutex))
      sleep(0.1)
      total_wait_time += 0.1
      if total_wait_time > 60 * 5
        raise "Took too long to obtain a lock"
      end
    end
    File.open(mutex_path(mutex), "w") {}
  end

  def release_lock(mutex)
    File.delete(mutex_path(mutex)) if File.exists? mutex_path(mutex)
  end

  private

  # returns the mutext path, making sure to only dump crap in tmp/
  def mutex_path(mutex)
    if mutex.start_with? 'tmp'
      mutex
    else
      'tmp/' << mutex
    end
  end

  # Given a mutex 'log/maintenance/walrus_maintenance.log',
  # ensures that 'tmp/log/maintenance/' directory exists
  def ensure_path_to_mutex(mutex)
    path = mutex_path(mutex)
    if path =~ /\Atmp\/.+\/([^\/]+)\z/
      FileUtils.mkdir_p path[0...-$1.length]
    end
  end
end

