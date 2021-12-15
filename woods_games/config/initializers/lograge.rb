Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.base_controller_class = 'ActionController::Base'
  config.lograge.ignore_actions = ['ZiddlerController#show', 'ChainController#show']
end