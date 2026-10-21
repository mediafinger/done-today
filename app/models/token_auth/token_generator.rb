module TokenAuth
  # Doorkeeper's access_token_generator. The prefix lets secret scanners recognize a
  #   leaked token: done_pat_ for personal access tokens, done_oat_ for OAuth apps.
  #
  module TokenGenerator
    def self.generate(options)
      prefix = options[:application] ? "done_oat_" : "done_pat_"

      prefix + SecureRandom.base58(44) # ~256 bits
    end
  end
end
