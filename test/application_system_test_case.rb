require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Configure for CI environment (GitHub Actions)
  if ENV['CI']
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |driver_option|
      driver_option.add_argument('--no-sandbox')
      driver_option.add_argument('--disable-dev-shm-usage')
      driver_option.add_argument('--disable-gpu')
      driver_option.add_argument('--remote-debugging-port=9222')
      driver_option.add_argument('--disable-web-security')
      driver_option.add_argument('--disable-extensions')
      driver_option.add_argument('--disable-features=VizDisplayCompositor')
      # Use a unique user data directory for each test run
      driver_option.add_argument("--user-data-dir=/tmp/chrome-test-#{Process.pid}-#{Time.now.to_i}")
    end
  else
    # Local development configuration
    driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
  end
end
