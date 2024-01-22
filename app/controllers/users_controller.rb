class UsersController < ApplicationController
  before_action :set_user, only: %i[ show edit update destroy request_signature]
  #before_action :authenticate, only: %i[request_signature]

  # GET /users or /users.json
  def index
    @users = User.all
  end

  # GET /users/1 or /users/1.json
  def show
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users or /users.json
  def create
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        format.html { redirect_to user_url(@user), notice: "User was successfully created." }
        format.json { render :show, status: :created, location: @user }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to user_url(@user), notice: "User was successfully updated." }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1 or /users/1.json
  def destroy
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url, notice: "User was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def request_signature
    pdf_path = Rails.root.join('lib', 'assets', 'f8879.pdf')
    account_info = authenticate
    full_name = @user.name + ' ' + @user.last_name

    args = {
      account_id: account_info[:account_id],
      base_path: account_info[:base_path],
      access_token: account_info[:access_token],
      signer_email: @user.email,
      signer_name: full_name,
      signer_ssn: @user.ssn,
      cc_email: @user.spouse_email,
      cc_name: @user.spouse_name,
      cc_ssn: @user.spouse_ssn,
      ds_ping_url: ENV['DS_PING_URL'],
      signer_client_id: 1,
      pdf_filename: pdf_path
    }
    
    @integration_key = ENV['DOCUSIGN_INTEGRATION_KEY']
    @url = FocusedViewService.new(args).worker
    render 'users/request_signature'
  rescue DocuSign_eSign::ApiError => e
    puts e.message
    puts e.response_body
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def user_params
      params.require(:user).permit(:name, :last_name, :ssn, :email, :spouse_name, :spouse_ssn, :spouse_email)
    end

    def get_consent
      url_scopes = $SCOPES.join('+')
      # Construct consent URL
      redirect_uri = 'https://developers.docusign.com/platform/auth/consent'
      consent_url = "https://#{ENV['AUTHORIZATION_SERVER']}/oauth/auth?response_type=code&" \
                    "scope=#{url_scopes}&client_id=#{ENV['DOCUSIGN_INTEGRATION_KEY']}&" \
                    "redirect_uri=#{redirect_uri}"
    
      puts 'Open the following URL in your browser to grant consent to the application:'
      puts consent_url
    end
    
    def authenticate
      configuration = DocuSign_eSign::Configuration.new
      configuration.debugging = true
      api_client = DocuSign_eSign::ApiClient.new(configuration)
      api_client.set_oauth_base_path(ENV['AUTHORIZATION_SERVER'])
    
      rsa_pk_path = Rails.root.join('lib', 'assets', 'docusign_private_key.txt')
      rsa_pk = File.read(rsa_pk_path)
      begin
        $SCOPES = %w[
          signature impersonation
        ]

        token = api_client.request_jwt_user_token(ENV['DOCUSIGN_INTEGRATION_KEY'], ENV['IMPERSONATED_USER_GUID'], rsa_pk, 3600, $SCOPES)
        user_info_response = api_client.get_user_info(token.access_token)
        account = user_info_response.accounts.find(&:is_default)
    
        {
          access_token: token.access_token,
          account_id: account.account_id,
          base_path: account.base_uri
        }
      rescue OpenSSL::PKey::RSAError => e
        Rails.logger.error e.inspect
    
        raise "Please add your private RSA key to: #{rsa_pk}" if File.read(rsa_pk).starts_with? '{RSA_PRIVATE_KEY}'
    
        raise
      rescue DocuSign_eSign::ApiError => e
        body = JSON.parse(e.response_body)
        if body['error'] == 'consent_required'
         # authenticate if get_consent
        else
          puts 'API Error'
          puts body['error']
          puts body['message']
          exit
        end
      end
    end
end
