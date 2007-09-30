require File.dirname(__FILE__) + '/../../spec_helper'
   


describe Card, "with hard tag template" do
  before do
    User.as :joe_user
    @bt = Card.create! :name=>"birthday+*template", :extension_type=>'HardTemplate',
      :type=>'Date', :content=>"Today!"
    @jb =  Card.create! :name=>"Jim+birthday"
  end       

  it "should have a hard tag template" do
    Card['birthday+*template'].extension_type.should=='HardTemplate'
  end

  it "should change cardtype with template" do
    # @bt.update_attributes!(:type => 'Basic'); @bt.save!
    @bt.type = 'Basic'; @bt.save!
    Card['Jim+birthday'].type.should == 'Basic'
  end   
  


  it "should have default cardtype" do
    @jb.type.should == 'Date'
  end
  it "should have default content" do
    @jb.content.should == 'Today!'
  end        
  
  it "should change content with template" do
    @bt.content = "Tomorrow"; @bt.save!
    Card['Jim+birthday'].content.should == 'Tomorrow'
  end 
  
  it "should not let you change the type" do
    @jb.ok?(:type).should_not be_true
  end
 
end

=begin

describe Card, "with soft tag template" do
  before do 
    User.as :admin do
      @bt = Card.create! :name=>"birthday+*template", :extension_type=>'SoftTemplate', 
              :type=>'Date', :content=>"Today!"
      @bt.permit(:comment, Role['auth']);  @bt.permit(:delete, Role['admin'])
      @bt.save!
    end
    User.as :joe_user
    @jb = Card.create! :name=>"Jim+birthday"
  end
  
  it "should have default cardtype" do
    @jb.type.should == 'Date'
  end
  
  it "should have default content" do
    Card['Jim+birthday'].content.should == 'Today!'
  end
  
  it "should have default permissions" do
    [:read, :edit, :comment, :delete].each do |task| 
      @jb.who_can(task).should== @bt.who_can(task)
    end
  end
end

describe Card, "with hard type template and hard tag template" do
  before do
    User.as :joe_user
    @bt = Card.create! :name=>"birthday+*template", :extension_type=>'HardTemplate',
      :type=>'Date', :content=>"Today!"      
    @dt = Card.create! :name=>"Date+*template", :extension_type=>'HardTemplate', :type=>'Date', :content=>'Tomorrow'
    @jb =  Card.create! :name=>"Jim+birthday"
  end       
  
  it "should have cardtype content" do
    @jb.content.should == 'Tomorrow'
  end
  
  it "should change content with cardtype" do
    @dt.content = 'Yesterday'; @dt.save!
    Card['Jim+birthday'].content.should== 'Yesterday'
  end
  
end


describe Card, "with soft type template" do
  
end

=end  
