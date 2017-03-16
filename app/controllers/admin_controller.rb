class AdminController < ApplicationController
	skip_before_action :verify_authenticity_token

  def index
  	# 判断是否consent
  	@account = Account.find_by_o365_email(cookies[:o365_login_email])
  end

  def consent
  	consent_url = "https://login.microsoftonline.com/common/oauth2/authorize?response_type=code&client_id=#{Settings.edu_graph_api.app_id}&resource=https://graph.windows.net&redirect_uri=#{Settings.redirect_uri}&state=12345&prompt=admin_consent"

  	redirect_to consent_url
  end

  def unconsent
    servicePrincipals = "https://graph.windows.net/#{Settings.tenant_name}/servicePrincipals/?api-version=beta"
    res = JSON.parse(HTTParty.get(servicePrincipals, headers: {
      "Authorization" => "#{session[:token_type]} #{session[:gwn_access_token]}",
      "Content-Type" => "application/x-www-form-urlencoded"
    }).body)['value']
    
    obj = res.find{ |_| _['appId'] == Settings.edu_graph_api.app_id }
    if obj
      res = HTTParty.delete("https://graph.windows.net/#{Settings.tenant_name}/servicePrincipals/#{obj['objectId']}?api-version=beta", headers: {
        "Authorization" => "#{session[:token_type]} #{session[:gwn_access_token]}",
        "Content-Type" => "application/x-www-form-urlencoded"
      })

      account = Account.find_by_o365_email(cookies[:o365_login_email])
      account.is_consent = false
      account.save

      Account.where("o365_email is not null and email is not null and o365_email != ?", cookies[:o365_login_email]).each do |_account|
        _account.update({o365_email: nil})
      end
    end

    redirect_to admin_index_path
  end

  def add_app_role_assignments
    servicePrincipals = "https://graph.windows.net/#{Settings.tenant_name}/servicePrincipals/?api-version=beta"
    res = JSON.parse(HTTParty.get(servicePrincipals, headers: {
      "Authorization" => "#{session[:token_type]} #{session[:gwn_access_token]}",
      "Content-Type" => "application/x-www-form-urlencoded"
    }).body)['value']
    
    obj = res.find{ |_| _['appId'] == Settings.edu_graph_api.app_id }
    # p obj

    if obj
      resourceId = obj['objectId']
      resoucreName = obj['displayName']
      user_url_with_roles = "https://graph.windows.net/#{Settings.tenant_name}/users?api-version=1.5&$expand=appRoleAssignments"
      users = JSON.parse(HTTParty.get(user_url_with_roles, headers: {
        "Authorization" => "#{session[:token_type]} #{session[:gwn_access_token]}",
        "Content-Type" => "application/x-www-form-urlencoded"
      }).body)['value']

      users.each do |user|
        # p user['objectId']
        next if user['appRoleAssignments'].find{|_user| _user['resourceId'] == resourceId }

        res = JSON.parse(HTTParty.post("https://graph.windows.net/#{Settings.tenant_name}/users/#{user['objectId']}/appRoleAssignments?api-version=1.5", headers: {
          "Authorization" => "#{session[:token_type]} #{session[:gwn_access_token]}",
          "Content-Type" => "application/json"
        }, body: {
          "resourceId" => resourceId,
          "principalId" => user['objectId']
        }.to_json).body)

        # p res
      end
    end
    
    redirect_to admin_index_path
  end

  def unlink_account
  	account_id = params[:account_id]
  	@account = Account.find(account_id)

  	if request.post?
  		@account.o365_email = nil
  		@account.save
  		redirect_to linked_accounts_admin_index_path
  	end
  end

  def linked_accounts
  	@accounts = Account.where("o365_email is not null and email is not null")
  end
end
