require 'json'

class DatabaseReq::SettingsController < ApplicationController
    
  # GET method to get all addresses of the user from database
  def index
    required = [:firebase_token]
    if required.all? {|k| params.has_key? k} #http://localhost:3000/addresses?one=1&two=2&three=3
      # here you know params has all the keys defined in required array
      data= get_user_id(params[:firebase_token])
      id=nil
      verified="false"
      unless data.nil?
        id = data["user_id"]
        verified = data["email_verified"]
      end
      unless id.nil? && verified == "false"
        user = User.new
        user.id = id
        if User.exists?(id: user.id)
          user = User.find(id)
        else
          user.save
        end
        setting = Setting.where("entity_id = :user",{user: user.id}).take
        render :json => { :code => "500", :status => "OK", :message => "Done.", :settings => setting.as_json(root: true) }
      else
        render :json => { :code => "401", :status => "Error", :message => "Not authorized." }
      end
    else
      render :json => { :code => "400", :status => "Error", :message => "Bad request." }
    end
  end
  
  # POST method for defining user addresses
  def create
    required = [:firebase_token, :results_shown, :tracking]
    if required.all? {|k| params.has_key? k} #http://localhost:3000/addresses?one=1&two=2&three=3
      # here you know params has all the keys defined in required array
      data= get_user_id(params[:firebase_token])
      id=nil
      verified="false"
      unless data.nil?
        id = data["user_id"]
        verified = data["email_verified"]
      end
      unless id.nil? && verified == "false"
        user = User.new
        user.id = id
        if User.exists?(id: user.id)
          user = User.find(id)
        else
          user.save
        end
        unless Setting.where("entity_id = :user",{user: user.id}).exists?
          if params[:results_shown].to_i>=5 && params[:results_shown].to_i<=10 && (params[:tracking]=="true" || params[:tracking]=="false")
            setting = Setting.new
            setting.results_shown = params[:results_shown]
            setting.tracking = params[:tracking]
            setting.entity_id = user.id
            firebase = Firebase::Client.new(ENV['FIREBASE_PROJECT_DATABASE_URI'], ENV['FIREBASE_SDK_SECRET'])
            response = firebase.push("user/#{id}/settings", {results_shown: setting.results_shown, tracking: setting.tracking, :created => Firebase::ServerValue::TIMESTAMP})
            setting.firebase_id = (JSON.parse(response.raw_body)['name'])
            setting.save
            render :json => {:code => "500", :status => "OK", :message => "Settings correctly created."}
          else
            render :json => {:code => "409", :status => "Conflict", :message => "Unacceptable params."}
          end
        else
          render :json => {:code => "409", :status => "Conflict", :message => "User has already defined its settings." }
        end
      else
        render :json => {:code => "401", :status => "Error", :message => "Not authorized." }
      end
    else
      render :json => {:code => "400", :status => "Error", :message => "Bad request." }
    end
  end
  
  # PUT method for updating in database an address (id in the link)
  def update
   required = [:firebase_token, :results_shown, :tracking]
    if required.all? {|k| params.has_key? k} #http://localhost:3000/addresses?one=1&two=2&three=3
      # here you know params has all the keys defined in required array
      data= get_user_id(params[:firebase_token])
      id=nil
      verified="false"
      unless data.nil?
        id = data["user_id"]
        verified = data["email_verified"]
      end
      unless id.nil? && verified == "false"
        if User.exists?(id: id)
          user = User.find(id)
          if Setting.where("entity_id = :user",{user: user.id}).exists?
            if params[:results_shown].to_i>=5 && params[:results_shown].to_i<=10 && (params[:tracking]=="true" || params[:tracking]=="false")
              setting = Setting.where("entity_id = :user",{user: user.id}).take
              firebase = Firebase::Client.new(ENV['FIREBASE_PROJECT_DATABASE_URI'], ENV['FIREBASE_SDK_SECRET'])
              unless setting.firebase_id.nil?
                response=firebase.update("user/#{id}/settings/#{setting.firebase_id}",{:results_shown => params[:results_shown], :tracking => params[:tracking], :created => Firebase::ServerValue::TIMESTAMP},{})
                if(response.code==400)
                  firebase.delete("user/#{id}/settings/#{setting.firebase_id}",{})
                  response = firebase.push("user/#{id}/settings", {results_shown: params[:results_shown], tracking: params[:tracking], :created => Firebase::ServerValue::TIMESTAMP})
                  setting.update(:results_shown => params[:results_shown], :tracking => params[:tracking], :firebase_id =>(JSON.parse(response.raw_body)['name']))
                else
                  setting.update(:results_shown => params[:results_shown], :tracking => params[:tracking])
                end
                render :json => {:code => "500", :status => "OK", :message => "Registered."}
              else
                response = firebase.push("user/#{id}/settings", {results_shown: params[:results_shown], tracking: params[:tracking], :created => Firebase::ServerValue::TIMESTAMP})
                setting.update(:results_shown => params[:results_shown], :tracking => params[:tracking], :firebase_id =>(JSON.parse(response.raw_body)['name']))
                render :json => {:code => "500", :status => "OK", :message => "Registered + Sync." }
              end
            else
              render :json => {:code => "409", :status => "Conflict", :message => "Unacceptable params."}
            end
          else
            render :json => {:code => "204", :status => "No Content", :message => "User hasn't created its settings yet." }
          end
        else
          render :json => {:code => "204", :status => "No Content", :message => "User hasn't created its settings yet." }
        end
      else
        render :json => {:code => "401", :status => "Error", :message => "Not authorized." }
      end
    else
      render :json => {:code => "400", :status => "Error", :message => "Bad request." }
    end
  end
  
  #DELETE (id in the link)
  def destroy
    render :json => {:code => "400", :status => "Error", :message => "Action not supported." }
  end
  
  #unused
  # GET method for editing a product based on id
  def edit
    render :json => {:code => "400", :status => "Error", :message => "Action not supported." }
  end
  
  # GET method to get a product by id
  def show
    render :json => {:code => "400", :status => "Error", :message => "Action not supported." }
  end
 
  # GET method for the new product form
  def new
    render :json => {:code => "400", :status => "Error", :message => "Action not supported." }
  end
  
  private
  
  def get_user_id(token)
    certificate_url = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
    myresponse = RestClient.get(certificate_url).body
    certificates  = JSON.parse myresponse.gsub('=>', ':')
    myjson =""
    certificates.each do|key , value|
      begin
        x509 = OpenSSL::X509::Certificate.new(value)
        iss = "https://securetoken.google.com/#{ENV['FIREBASE_PROJECT_ID']}"
        aud = ENV['FIREBASE_PROJECT_ID']
        myjson = JWT.decode(token, x509.public_key, true, 
        {               algorithm: "RS256", verify_iat: true ,
                       iss: iss , verify_iss: true ,
                       aud: aud , verify_aud: true
        })
        return myjson[0]
      rescue
      end
    end
    return nil     
  end
end
