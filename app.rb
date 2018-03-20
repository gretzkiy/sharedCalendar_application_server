require 'sinatra'
require 'nokogiri'
require 'json'

helpers do
  def user_exists?(user_login)
    doc = Nokogiri::XML(File.read('./users.xml'))
    doc.css("users user[login = #{user_login}]").children.empty? ? false : true
  end

  def password_correct?(user_login, user_password)
    doc = Nokogiri::XML(File.read('./users.xml'))
    doc.css("users user[login = #{user_login}] password").text == user_password
  end

  def new_user?(user_login, user_password, name, surname, patronymic)
    doc = Nokogiri::XML(File.read('./users.xml'))

    user_node = Nokogiri::XML::Node.new('user', doc)
    user_node.set_attribute('login', user_login)

    password_node = Nokogiri::XML::Node.new('password', doc)
    password_node.content = user_password

    name_node = Nokogiri::XML::Node.new('name', doc)
    name_node.content = name

    surname_node = Nokogiri::XML::Node.new('surname', doc)
    surname_node.content = surname

    patronymic_node = Nokogiri::XML::Node.new('patronymic', doc)
    patronymic_node.content = patronymic

    user_node << password_node
    user_node << name_node
    user_node << surname_node
    user_node << patronymic_node
    doc.root << user_node

    !File.write('./users.xml', doc.to_xml).zero?
  end

  def user_groups(user_login)
    doc = Nokogiri::XML(File.read('./users.xml'))
    groups = doc.css("users user[login = #{user_login}] group")
    groups_hash = { 'amount' => groups.count, 'groups' => [] }
    groups.each { |e| groups_hash['groups'] << { 'id' => e['id'], 'name' => group_name_by_id(e['id']) } }
    groups_hash
  end

  def find_users(key)
    doc = Nokogiri::XML(File.read('./users.xml'))
    users = doc.css('users user').map { |e| e['login'] }.select { |e| e.upcase.start_with? key.upcase }
    users_hash = {'amount' => users.count, 'users' => users }
    # users.each { |e| users_hash['users'] << e }
    # users_hash
  end

  def users_in_group(group_id)
    doc = Nokogiri::XML(File.read('./users.xml'))
    users = doc.css("users user group[id = '#{group_id}']").map { |e| e.parent.attribute('login').text }
    {'amount' => users.count, 'users' => users }
  end

  def group_name_by_id(group_id)
    doc = Nokogiri::XML(File.read('./groups.xml'))
    doc.css("groups group").each { |group| return group.content if group['id'] == group_id.to_s }
    return 0
  end

  def new_group(group_name, group_admin)
    doc = Nokogiri::XML(File.read('./groups.xml'))
    groups = doc.css("groups group")
    group_id = groups.empty? ? 1 : groups.last['id'].to_i + 1

    group_node = Nokogiri::XML::Node.new('group', doc)
    group_node.content = group_name
    group_node.set_attribute('id', group_id)
    group_node.set_attribute('admin', group_admin)
    doc.root << group_node

    File.write('./groups.xml', doc.to_xml).zero? ? 0 : {'group_id' => group_id }
  end

  def add_users_to_group(members, group_id)
    doc = Nokogiri::XML(File.read('./users.xml'))

    doc.css("users user")
    .select { |user| members.include? user.attribute('login').text }
    .each do |user|
      group_node = Nokogiri::XML::Node.new('group', doc)
      group_node.set_attribute('id', group_id)
      user << group_node
    end

    !File.write('./users.xml', doc.to_xml).zero?
  end

  def new_fav(users_to, user_from)
    doc = Nokogiri::XML(File.read('./users.xml'))

    users_to.each do |user_to|
      doc.css("users user[login = #{user_to}] fav[status = unconfirmed]").each do |request|
        return true if request.text == user_from
      end
    end

    doc.css("users user[login = #{user_from}] fav[status = unconfirmed]").each do |request|
        return -1 if users_to.include? request.text
    end

    doc.css("users user")
    .select { |user| users_to.include? user.attribute('login').text }
    .each do |user|
      new_fav_node = Nokogiri::XML::Node.new('fav', doc)
      new_fav_node.content = user_from
      new_fav_node.set_attribute('status', 'unconfirmed')
      user << new_fav_node
    end

    !File.write('./users.xml', doc.to_xml).zero?
  end

  def unconfirmed_favs(login)
    doc = Nokogiri::XML(File.read('./users.xml'))
    requests = doc.css("users user[login = #{login}] fav[status = unconfirmed]").map { |req| req.text }
    {'amount' => requests.count, 'users' => requests }
  end

  def confirm_fav(user_to, user_from)
    doc = Nokogiri::XML(File.read('./users.xml'))

    fav_node = doc.css("users user[login = #{user_to}] fav[status = unconfirmed]")
                  .select { |fav| fav.text == user_from }.last

    return -1 if !fav_node

    fav_node.set_attribute('status', 'confirmed')

    user_node = doc.css("users user[login = #{user_from}]").select { |node| node.attribute('login').text == user_from }.last
    new_fav_node = Nokogiri::XML::Node.new('fav', doc)
    new_fav_node.content = user_to
    new_fav_node.set_attribute('status', 'confirmed')
    user_node << new_fav_node
    doc.root << user_node

    !File.write('./users.xml', doc.to_xml).zero?
  end

  def favs(login)
    doc = Nokogiri::XML(File.read('./users.xml'))
    favs = doc.css("users user[login = #{login}] fav[status = confirmed]").map { |fav| fav.text }
    {'amount' => favs.count, 'favs' => favs }
  end
end

get '/' do
  # status 200
  # 'Server available'
  File.read('./api_doc.html')
end

# /signup?login=kek&password=kek&name=kek&surname=kek&patronymic=kek
post '/signup' do
  login = params[:login]
  password = params[:password]
  name = params[:name]
  surname = params[:surname]
  patronymic = params[:patronymic]
  if user_exists? login
    status 409
    'Not signed up. Login already exists.'
  elsif new_user? login, password, name, surname, patronymic
    status 201
    'Signed up.'
  else
    status 500
    'Not signed up. Internal error.'
  end
end

# /signin?login=kek&password=kek
get '/signin' do
  login = params[:login]
  password = params[:password]
  if user_exists? login
    if password_correct? login, password
      status 202
      'Signed in.'
    else
      status 401
      'Not signed in. Invalid password.'
    end
  else
    status 401
    'Not signed in. No such user.'
  end
end

# /user_groups?login=myLogin
get '/user_groups' do
  login = params[:login]
  if user_exists? login
    content_type :json
    status 200
    user_groups(login).to_json
  else
    status 400
    'No such user.'
  end
end

# /find_users?key=adm
# ignores case
get '/find_users' do
  key = params[:key]
  content_type :json
  status 200
  find_users(key).to_json
end

# /users_in_group?group_id=1
get '/users_in_group' do
  group_id = params[:group_id]
  content_type :json
  status 200
  users_in_group(group_id).to_json
end

# /find_group?group_id=1
get '/find_group' do
  group_id = params[:group_id]
  group_name = group_name_by_id group_id
  if group_name != 0
    status 200
    group_name
  else
    status 400
    'No such group.'
  end
end

# /new_group?group_name=testGroup&group_admin=kek
post '/new_group' do
  group_name = params[:group_name]
  group_admin = params[:group_admin]
  group_id = new_group group_name, group_admin
  if group_id != 0
    content_type :json
    status 200
    group_id.to_json
  else
    status 500
    'Group was not created.'
  end
end

# /add_users_to_group?members[]=kek&members[]=admin&group_id=1
post '/add_users_to_group' do
  members = params[:members]
  group_id = params[:group_id]
  if add_users_to_group(members, group_id)
    status 200
    'Users were added.'
  else
    status 500
    'Users were not added.'
  end
end

# /new_favs?favs[]=kek&favs[]=elon_musk&from=userFrom
post '/new_favs' do
  users_to = params[:favs]
  user_from = params[:from]
  result = new_fav(users_to, user_from)

  if result == -1
    status 405
    'One is already waiting for confirmation.'
  elsif result
    status 200
    'Favs were added.'
  else
    status 500
    'Favs were not added.'
  end
end

# /unconfirmed_favs?login=kek
get '/unconfirmed_favs' do
  login = params[:login]
  content_type :json
  status 200
  unconfirmed_favs(login).to_json
end

# /confirm_fav?to_userTo&from=userFrom
post '/confirm_fav' do
  user_to = params[:to]
  user_from = params[:from]
  result = confirm_fav(user_to, user_from)

  if result == -1
    status 405
    'No such request.'
  elsif result
    status 200
    'Fav confirmed.'
  else
    status 500
    'Fav was not confirmed.'
  end
end

# /favs?login=user
get '/favs' do
  login = params[:login]
  content_type :json
  status 200
  favs(login).to_json
end

# /download_avatar?group_id=12
get '/download_avatar' do
  group_id = params[:group_id]
  file = Dir["./public/#{group_id}.*"]
  if file.empty?
    status 404
    'No avatar for such group'
  else
    send_file file[0]
    # cache_control :must_revalidate
  end
end

# /upload_avatar?group_id=12
post '/upload_avatar' do
  group_id = params[:group_id]
  extname = File.extname params[:file][:filename]
  filename = group_id + extname
  file = params[:file][:tempfile]
  Dir["./public/#{group_id}.*"].each { |f| File.delete f }
  File.open("./public/#{filename}", 'wb') do |f|
    f.write(file.read)
  end
end
