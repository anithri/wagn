class CardController < ApplicationController
  helper :wagn

  EDIT_ACTIONS = [ :edit, :update, :rollback, :save_draft, :watch, :unwatch,
    :create_account, :update_account ]
  LOAD_ACTIONS =  EDIT_ACTIONS + [ :show_file, :show, :index, :comment,
    :remove, :view, :changes, :options, :related ]

  before_filter :index_preload, :only=> [ :index ]
  
  before_filter :load_card!, :only=>LOAD_ACTIONS
  before_filter :set_main

  before_filter :view_ok,   :only=> LOAD_ACTIONS
#  before_filter :create_ok, :only=>[ :new, :create ]
  before_filter :update_ok, :only=> EDIT_ACTIONS
  before_filter :remove_ok, :only=>[ :remove ]



  #----------( CREATE )
  
  def create
    @card = Card.new params[:card]
    if @card.save
      render_success
    else
      render_card_errors      
    end
  end

  def create_or_update
    if @card = Card[ params[:card][:name] ]
      update
    else
      create
    end
  end


  #----------( READ )

  def show
    save_location if params[:format].nil? || params[:format].to_sym==:html
    render_show
  end

  def show_file
    if attachment? params[:format]
      warn "show_file #{params.inspect}"
      send_file card.attach.path, :type=>attach_content_type, :x_sendfile=>true
    end
    warn "show_file 2"
  end

  def index()    show                  end
  def view()     render_show           end
  def changes()  render_show :changes  end
  def options()  render_show :options  end
  def related()  render_show :related  end
  def edit()     render_show :edit     end


  def new
    args = params[:card] || {}
    params[:type] = ( args[:type] ||= params[:type] ) # for /new/:type shortcut

    @card = Card.new args
    if @card.ok? :create
      render_show :new
    else
      render_denied('create')
    end
  end


  #--------------( UPDATE )


  def update
    @card = @card.refresh # (cached card attributes often frozen)
    args=params[:card] || {}
    args[:typecode] = Cardtype.classname_for(args.delete(:type)) if args[:type]
    
    @card.update_attributes(args)

    if !@card.errors[:confirmation_required].empty?
      @card.confirm_rename = @card.update_referencers = true
      params[:attribute] = 'name'
      render_show :edit
    elsif !@card.errors.empty?
      render_card_errors
    else
      render_success
    end
  end


  ## the following three methods need to be merged into #update

  def save_draft
    @card.save_draft( params[:card][:content] )
    render :text=>'success'
  end

  def comment
    raise(Wagn::NotFound,"Action comment should be post with card[:comment]") unless request.post? and params[:card]
    @comment = params[:card][:comment];
    if User.current_user.login == 'anon'
      @author = params[:card][:comment_author]
      session[:comment_author] = @author
      @author = "#{@author} (Not signed in)"
    else
      username=User.current_user.card.name
      #@author = "{{#{username}+image|size:icon}} [[#{username}]]"
      @author = "[[#{username}]]"
    end
    @comment=@comment.split(/\n/).map{|c| "<p>#{c.empty? ? '&nbsp;' : c}</p>"}.join("\n")
    @card.comment = "<hr>#{@comment}<p><em>&nbsp;&nbsp;--#{@author}.....#{Time.now}</em></p>"
    @card.save!
    render_show
  end

  def rollback
    revision = @card.revisions[params[:rev].to_i - 1]
    @card.update_attributes! :content=>revision.content
    render_show
  end



  #------------( DELETE )

  def remove
    @card.confirm_destroy = params[:confirm_destroy]
    @card.destroy
    
    return render_show(:remove) if !@card.errors[:confirmation_required].empty?  ## renders remove.erb, which is essentially a confirmation box.  

    discard_locations_for(@card) 

    render_success 'REDIRECT: TO-PREVIOUS'
  end


  #-------- ( ACCOUNT METHODS )
  
  def update_account
    @extension = @card.extension 
    
    if params[:save_roles]
      User.ok! :assign_user_roles
      role_hash = params[:user_roles] || {}
      @extension.roles = Role.find role_hash.keys
    end

    if @extension && params[:extension]
      @extension.update_attributes!(params[:extension])
    end
    
    flash[:notice] ||= "Got it!  Your changes have been saved."  #ENGLISH
    params[:attribute] = :account
    render_show :options
  end

  def create_account
    User.ok!(:create_accounts) && @card.ok?(:update)
    email_args = { :subject => "Your new #{Wagn::Conf[:site_title]} account.",   #ENGLISH
                   :message => "Welcome!  You now have an account on #{Wagn::Conf[:site_title]}." } #ENGLISH
    @user, @card = User.create_with_card(params[:user],@card, email_args)
    raise ActiveRecord::RecordInvalid.new(@user) if !@user.errors.empty?
    @extension = User.new(:email=>@user.email)
#    flash[:notice] ||= "Done.  A password has been sent to that email." #ENGLISH
    params[:attribute] = :account
    render_show :options
  end

  
  #-------- ( MISFIT METHODS )
  
  
  def watch
    watchers = Card.fetch_or_new( @card.cardname.star_rule(:watchers ) )
    watchers = watchers.refresh if watchers.frozen?
    watchers.add_item User.current_user.card.name
    #flash[:notice] = "You are now watching #{@card.name}"
    ajax? ? render(:inline=>%{<%= get_slot.watch_link %>}) : view
  end

  def unwatch
    watchers = Card.fetch_or_new( @card.cardname.star_rule(:watchers ) )
    watchers = watchers.refresh if watchers.frozen?
    watchers.drop_item User.current_user.card.name
    #flash[:notice] = "You are no longer watching #{@card.name}"
    ajax? ? render(:inline=>%{<%= get_slot.watch_link %>}) : view
  end

  private
  
  #-------( FILTERS )
  
  def index_preload
    User.no_logins? ? 
      redirect_to( Card.path_setting '/admin/setup' ) : 
      params[:id] = (Card.setting('*home') || 'Home').to_cardname.to_url_key
  end
  
  def set_main
    Wagn::Conf[:main_name] = params[:main] || (@card && @card.name) || '' # will be wagn.main ?
  end
  
  
  #---------( RENDER HELPERS)
  
  def render_show(view = nil)
    extension = request.parameters[:format]
    return "unknown format: #{extension}" unless
              FORMATS.split('|').member?( extension ) || show_file

    render(:text=> begin
      respond_to() do |format|
        format.send(extension) do
          renderer = Wagn::Renderer.new(@card, :format=>extension, :controller=>self)
          renderer.render_show :view=>view
        end
      end
    end)
  end
  
  def render_success(default_target='TO-CARD')
    target = params[:success] || default_target
    redirect = !ajax?

    if target =~ /^REDIRECT:\s*(.+)/
      redirect, target = true, $1
    end
    
    target = case target
      when 'TO-PREVIOUS'   ;  previous_location
      when 'TO-CARD'       ;  @card
      when /^(http|\/)/    ;  target
      when /^TEXT:\s*(.+)/ ;  $1
      else                 ;  Card.fetch_or_new(target)
      end
    
    case
    when  redirect        ; wagn_redirect ( Card===target ? card_path(target) : target )
    when  String===target ; render :text => target 
    else  @card = target  ; render_show
    end
  end

end

