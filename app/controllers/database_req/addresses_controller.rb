require 'json'

class DatabaseReq::AddressesController < ApplicationController
  
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
        addresses= Address.where("entity_id = :id",{id: id})
        render :json => { :code => "500", :status => "OK", :message => "Done.", :addresses => addresses.as_json(root: false) }
      else
        render :json => { :code => "401", :status => "Error", :message => "Not authorized." }
      end
    else
      render :json => { :code => "400", :status => "Error", :message => "Bad request." }
    end
  end
  
  # POST method for defining user addresses
  def create
    required = [:firebase_token, :address]
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
        addresses= Address.where("entity_id = :id",{id: id})
        if addresses.length<ENV['MAX_ALLOWED_ADDRESSES'].to_i
          if Address.where("address = :add AND entity_id = :ent", {add: params[:address], ent: id}).exists?
            render :json => {:code => "409", :status => "Conflict", :message => "Address already registered."}
          else
            if params[:address].length>0 && params[:address].length<=70
              firebase = Firebase::Client.new(ENV['FIREBASE_PROJECT_DATABASE_URI'], ENV['FIREBASE_SDK_SECRET'])
              unless params[:latitude].nil? || params[:longitude].nil?
                address = Address.new
                address.address=params[:address]
                address.latitude=params[:latitude]
                address.longitude=params[:longitude]
                address.entity_id = id
                response = firebase.push("user/#{id}/addresses", {address: address.address, latitude: address.latitude, longitude: address.longitude, :created => Firebase::ServerValue::TIMESTAMP})
                address.firebase_id =  (JSON.parse(response.raw_body)['name'])
                address.save
                render :json => {:code => "500", :status => "OK", :message => "Address correctly created."}
              else
                address = Address.new
                address.address=params[:address]
                address.entity_id = id
                address.entity_type = 'User'
                response = firebase.push("user/#{id}/addresses", {address: address.address, :created => Firebase::ServerValue::TIMESTAMP})
                address.firebase_id =  (JSON.parse(response.raw_body)['name'])
                address.save
                render :json => {:code => "500", :status => "OK", :message => "Address created, but withouth coordinates."}
              end
            else
              render :json => {:code => "400", :status => "Error", :message => "Address too long."}
            end
          end
        else
          render :json => {:code => "409", :status => "Conflict", :message => "You have reached already the address limit."}
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
   required = [:firebase_token, :address]
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
          if Address.where("address = :address_searched AND entity_id = :user_id",{address_searched: params[:address], user_id: user.id}).exists?
            address= Address.where("address = :address_searched AND entity_id = :user_id",{address_searched: params[:address], user_id: user.id}).take
            unless params[:new_address].nil?
              if params[:address].length>0 && params[:address].length<=70
                 unless Address.where("address = :address_searched AND entity_id = :user_id",{address_searched: params[:new_address], user_id: user.id}).exists?
                   firebase = Firebase::Client.new(ENV['FIREBASE_PROJECT_DATABASE_URI'], ENV['FIREBASE_SDK_SECRET'])
                   unless params[:latitude].nil? or params[:longitude].nil?
                     unless address.firebase_id.nil?
                       response=firebase.update("user/#{id}/addresses/#{address.firebase_id}",{latitude: params[:latitude], longitude: params[:longitude], address: params[:new_address], created: Firebase::ServerValue::TIMESTAMP},[])       
                       if(response.code==400)
                         firebase.delete("user/#{id}/addresses/#{address.firebase_id}",{})
                         response = firebase.push("user/#{id}/addresses", {latitude: params[:latitude], longitude: params[:longitude], address: params[:new_address], created: Firebase::ServerValue::TIMESTAMP})
                         address.update(:latitude => params[:latitude], :longitude => params[:longitude], :address => params[:new_address], :firebase_id =>(JSON.parse(response.raw_body)['name']))
                       else
                         address.update(:latitude => params[:latitude], :longitude => params[:longitude], :address => params[:new_address])
                       end
                       render :json => {:code => "500", :status => "OK", :message => "Registered."}
                     else
                       response = firebase.push("user/#{id}/addresses", {latitude: params[:latitude], longitude: params[:longitude], address: params[:new_address], created: Firebase::ServerValue::TIMESTAMP})
                       address.update(:latitude => params[:latitude], :longitude => params[:longitude], :firebase_id => (JSON.parse(response.raw_body)['name']), :address => params[:new_address])
                       render :json => {:code => "500", :status => "OK", :message => "Registered + Sync."}
                     end
                   else
                     unless address.firebase_id.nil?
                       response=firebase.update("user/#{id}/addresses/#{address.firebase_id}",{address: params[:new_address], created: Firebase::ServerValue::TIMESTAMP},{})
                       if(response.code==400)
                         firebase.delete("user/#{id}/addresses/#{address.firebase_id}",{})
                         response = firebase.push("user/#{id}/addresses", {address: params[:new_address], created: Firebase::ServerValue::TIMESTAMP})
                         address.update(:address => params[:new_address], :firebase_id =>(JSON.parse(response.raw_body)['name']))
                       else
                         address.update(:address => params[:new_address])
                       end
                       render :json => {:code => "500", :status => "OK", :message => "Registered."}
                     else
                       response = firebase.push("user/#{id}/addresses", {address: params[:new_address], latitude: address.latitude, longitude: address.longitude, created: Firebase::ServerValue::TIMESTAMP})
                       address.update(:address => params[:new_address], :firebase_id => (JSON.parse(response.raw_body)['name']))
                       render :json => {:code => "500", :status => "OK", :message => "Registered + Sync." }
                     end
                   end
                 else
                   render :json => {:code => "409", :status => "Conflict", :message => "New Address already exists." }
                 end
              else
                render :json => {:code => "409", :status => "Conflict", :message => "Address too long."}  
              end
            else
               unless params[:latitude].nil? or params[:longitude].nil?
                 firebase = Firebase::Client.new(ENV['FIREBASE_PROJECT_DATABASE_URI'], ENV['FIREBASE_SDK_SECRET'])
                 unless address.firebase_id.nil?
                   response=firebase.update("user/#{id}/addresses",address.firebase_id,{latitude: params[:latitude], longitude: params[:longitude], created: Firebase::ServerValue::TIMESTAMP});
                   if(response.code==400)
                     firebase.delete("user/#{id}/addresses/#{address.firebase_id}",{})
                     response = firebase.push("user/#{id}/addresses", {address: address.address, latitude: params[:latitude], longitude: params[:longitude], created: Firebase::ServerValue::TIMESTAMP})
                     address.update(:latitude => params[:latitude], :longitude => params[:longitude], :firebase_id =>(JSON.parse(response.raw_body)['name']))
                   else
                     address.update(:latitude => params[:latitude], :longitude => params[:longitude])
                   end
                   render :json => {:code => "500", :status => "OK", :message => "Registered." }
                 else
                   response = firebase.push("user/#{id}/addresses", {address: address.address, latitude: params[:latitude], longitude: params[:longitude], created: Firebase::ServerValue::TIMESTAMP})
                   address.update(:latitude => params[:latitude], :longitude => params[:longitude], :firebase_id => (JSON.parse(response.raw_body)['name']))
                   render :json => {:code => "500", :status => "OK", :message => "Registered + Sync." }
                 end
               else
                 render :json => {:code => "500", :status => "OK", :message => "No changes done." }
               end
            end
          else
            render :json => {:code => "204", :status => "No Content", :message => "Address pointed doesn't exists." }
          end
        else
          render :json => {:code => "204", :status => "No Content", :message => "User hasn't published anything yet." }
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
    required = [:firebase_token, :address]
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
          if Address.where("address = :address_searched AND entity_id = :user_id",{address_searched: params[:address], user_id: user.id}).exists?
            firebase = Firebase::Client.new(ENV['FIREBASE_PROJECT_DATABASE_URI'], ENV['FIREBASE_SDK_SECRET'])
            address= Address.where("address = :address_searched AND entity_id = :user_id",{address_searched: params[:address], user_id: user.id}).take
            response= firebase.delete("user/#{id}/addresses/#{address.firebase_id}",{})
            if(response.code==200)
              address.destroy
              render :json => {:code => "500", :status => "OK", :message => "Address deleted." }
            else
              render :json => {:code => "400", :status => "Error", :message => "Cannot delete from cloud storage." }
            end
          else
            render :json => {:code => "204", :status => "No Content", :message => "Address pointed doesn't exists." }
          end
        else
          render :json => {:code => "204", :status => "No Content", :message => "User hasn't published anything yet." }
        end
      else
        render :json => {:code => "401", :status => "Error", :message => "Not authorized." }
      end
    else
      render :json => {:code => "400", :status => "Error", :message => "Bad request." }
    end
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
