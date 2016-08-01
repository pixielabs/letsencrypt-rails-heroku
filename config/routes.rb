Rails.application.routes.draw do
  if Letsencrypt.challenge_configured? 
    get "/#{ENV["ACME_CHALLENGE_FILENAME"]}" => proc {|env| [200, {}, [ENV["ACME_CHALLENGE_FILE_CONTENT"]]] }
  end
end
