require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Card do
  before do
    User.as(:wagbot)
  end
  
  context "settings" do
    it "retrieves pattern based value" do
      Card.create :name => "Book cards", :type => "Pattern", :content => "{\"type\": \"Book\"}"
      Card.create :name => "Book cards+*new", :content => "authorize"
      Card.new( :type => "Book" ).setting('new').should == "authorize"
    end                                          
    
    it "retrieves default values" do
      Card.create :name => "all Basic cards", :type => "Pattern", :content => "{\"type\": \"Basic\"}"  #defaults should work when other patterns are present
      Card.create :name => "*default+*new", :content => "lobotomize"
      Card.default_setting('new').should == "lobotomize"
      Card.new( :type => "Basic" ).setting('new').should == "lobotomize"
    end                                                                 
    
    it "retrieves single values" do
      Card.create :name => "banana+*+*edit", :content => "pebbles"
      Card["banana"].setting('edit').should == "pebbles"
    end
  end
  
end