require File.dirname(__FILE__) + '/../test_helper'
require 'mailer'

class MailerTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"

  include ActionMailer::Quoting

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
  end  
  
  def test_truth
    assert true
  end
  
  ## see notifier test for data used in these tests
  
  context "change_notice" do
    setup do
      user =  ::User.find_by_login('sara')
      card =  Card["Sunglasses"]
      action = "edited"
      
      Mailer.deliver_change_notice( user, card, action )
    end

    should "deliver a message" do
      assert_equal 1, ActionMailer::Base.deliveries.size
    end
    
    context "message" do
      setup do
        @mail = ActionMailer::Base.deliveries[0]
      end
      should "be addressed to users email" do
        assert_equal ["sara@user.com"],  @mail.to
      end
    end
  end
  

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/user_notifier/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end