module SessionKey

	def get_seed()
		now = Time.now.utc

		return now.year * 10000 + now.month * 100 + now.day
	end

	def get_ttl()
		now = Time.now.utc

		return 86400 - now.hour * 3600 - now.min * 60 - now.sec
	end

	def gen_chars(seed, length)
		random = Random.new(seed)

		text = ''

		for i in 0..(length - 1)
			v = (random.rand * 36).floor()

			if (v < 10)
				text += (48 + v).chr()
			else
				text += (97 + v - 10).chr()
			end
		end

		return text
	end

	# assume that input text consist of all capital letters
	def rot_chars(seed, text, value)
		rotd = ''

		text.each_byte do |v|
			v += value
			v += 26 if v < 65
			v -= 26 if v > 90

			rotd += v.chr()
		end

		return rotd
	end

	def SSK_encode(country_code, premium = nil)
		 if (country_code == nil || country_code.length != 3)
			country_code = 'KOR' 
		end
		seed = get_seed()
		
		is_premium = 'P'
		is_premium = premium ? 'P' : 'N' unless premium.nil?
		is_premium_char = rot_chars(seed, is_premium, (seed % 7) + 2).downcase
		return gen_chars(seed, 13) + rot_chars(seed, country_code, (seed % 7) + 3).downcase + is_premium_char
	end

	def SSK_decode(session_key)
		if (session_key == nil || !(session_key.length == 17 || session_key.length == 16) )
			return false, 'KOR' 
		end

		seed = get_seed()
		success = gen_chars(seed, 13).eql? session_key[0, 13]
		country_code = rot_chars(seed, session_key[13, 3].upcase, -(seed % 7) - 3)
		
		is_premium = false
		is_premium_char = rot_chars(seed, session_key[16,1].upcase, -(seed % 7) - 2) if session_key.length == 17
		is_premium = is_premium_char=='P' ? true : false if session_key.length == 17

		return success, country_code, get_ttl(), is_premium
	end

	def simple_token_decode(token)
		seed = get_seed
		decoded = rot_chars(seed, token.upcase, -(seed % 7) - 2)
		decoded
	end

	def is_valid_simple_token(token)
		word_arrays = ['PQPEROBE','RBEQWRR','BEREDQEK','ONBOEPPW']
		word_arrays.include?(simple_token_decode(token)) ? true : false
	end


end

# seed = get_seed();

# p "SEED: #{seed}"

# p gen_chars(seed, 13)
# p gen_chars(seed, 13)

# p SSK_decode(nil)
# p get_ttl()

# p SSK_encode('USA')
# p SSK_encode('USA')[0, 13]
# p SSK_encode('USA')[0, 13].eql? gen_chars(seed, 13)

# p rot_chars(seed, 'USA', 3)
# p rot_chars(seed, 'XVD', -3)
# p rot_chars(seed, 'KOR', 4)
# p rot_chars(seed, 'OSV', -4)

# p SSK_decode('ezcth1t4a1hknxvd')
# p SSK_decode('ezcth1t4a1hknnru')