require 'alipay'
require 'net/http'
require 'uri'
require 'json'

#需要支付宝gem
gem 'alipay', '~> 0.15.1'

def zfb_login
    begin
      logger.info '通过支付包返回用户的信息'
      api_url = 'https://openapi.alipay.com/gateway.do'
      app_id = Rails.application.credentials[:zfb][:app_id]
      app_private_key = "-----BEGIN PRIVATE KEY-----\n#{you app_private_key 你的app_private_key ,左右两边必须写}\n-----END PRIVATE KEY-----\n"
      alipay_public_key = "-----BEGIN PUBLIC KEY-----\n#{you alipay_public_key}\n-----END PUBLIC KEY-----\n"
      sign_type = 'RSA2'
      charset = 'GBK'
      version = '1.0'
	  #前端返回给你的code
      code = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

      time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      # time = '2019-07-24 20:12:40'

      @alipay_client = Alipay::Client.new(
        url: api_url,
        app_id: app_id,
        app_private_key: app_private_key,
        alipay_public_key: alipay_public_key,
        sign_type: sign_type
      )
      datta = {
          app_id: app_id,
          code: code,
          charset: charset,
          method: 'alipay.system.oauth.token',
          sign_type: sign_type,
          timestamp: time,
          version: version,
          grant_type: 'authorization_code'
      }

      sign = @alipay_client.sign(datta)
      logger.info "获取sign#{sign}"

      #获取用户token
      uri = URI('https://openapi.alipay.com/gateway.do')
      res = Net::HTTP.post_form(uri, 'app_id' => app_id,
                                     'method' => 'alipay.system.oauth.token',
                                     'charset' => charset,
                                     'sign_type' => sign_type,
                                     'timestamp' => time,
                                     'sign' => sign,
                                     'version' => version,
                                     'grant_type' => 'authorization_code',
                                     'code' => code)
      resbody = JSON.parse(res.body)
      access_token = resbody['alipay_system_oauth_token_response']['access_token']
      if access_token.present?
        datta_user = {
          'app_id' => app_id,
          'method' => 'alipay.user.info.share',
          'charset' => charset,
          'sign_type' => sign_type,
          'timestamp' => time,
          'version' => version,
          'auth_token' => access_token
        }


        sign_user = @alipay_client.sign(datta_user)
        logger.info "获取sign_user#{sign_user}"
        # get user' info
        # contentType: "application/json;charset=utf-8"
        uri_user = URI('https://openapi.alipay.com/gateway.do')
        uri_user = Net::HTTP.post_form(uri_user, 'app_id' => app_id,
                                                 'method' => 'alipay.user.info.share',
                                                 'charset' => charset,
                                                 'sign_type' => sign_type,
                                                 'timestamp' => time,
                                                 'sign' => sign_user,
                                                 'version' => version,
                                                 'auth_token' => access_token)
        resbody_user = JSON.parse(uri_user.body)

        zfb_user = resbody_user['alipay_user_info_share_response']
        if zfb_user['code'] == '10000'
          login_way = '2'
          other_account = "ZFB_#{zfb_user['user_id']}"


          # encoding: UTF-8
          user_name = zfb_user['nick_name'].encode('utf-8', 'gbk', {:invalid => :replace, :undef => :replace, :replace => '?'})

          user_sex = if zfb_user['gender'] == 'm'
                       '0'
                     elsif zfb_user['gender'] == 'f'
                       '1'
                     else
                       '-1'
                     end
          user_img = zfb_user['avatar'].to_s

          euser = EUser.find_by(other_account: other_account)

          #如果qq号不是第一次登录，直接登录
          if !euser.present?
			#EUser为entity,这里就不写出来了other_account是唯一值,我在签名加了ZFB桑字符串,不需要可以去掉
            new_euser = EUser.new(account: other_account,
                                  other_account: other_account,
                                  login_way: login_way,
                                  password: other_account,
                                  e_name: user_name, e_sex: user_sex,
                                  e_image: user_img,
                                  user_login_time: Time.now)
            if new_euser.save
              return render json: Result.new(0000, '', {user: new_euser, server_info: nil}), status: 200
            else
              return render json: Result.new(1111, '登录失败', '')
            end
          end


        else
          return render json: Result.new(1111, '登录失败', ''), status: 200
        end

      else
        return render json: Result.new(1111, '登录失败', ''), status: 200
      end
    rescue Exception => err
      logger.error "解锁音乐包错误:#{err.message}"
      return render json: {code: 4444, msg: '服务错误' + err.message}, status: 200
    end
  end