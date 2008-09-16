require File.dirname(__FILE__) + '/spec_helper.rb'

include RR

describe SyncRunner do
  before(:each) do
  end

  it "rrsync.rb should call ScanRunner#run" do
    SyncRunner.should_receive(:run).with(ARGV).and_return(0)
    Kernel.any_instance_should_receive(:exit) {
      load File.dirname(__FILE__) + '/../bin/rrsync.rb'
    }
  end

  it "execute should sync the specified tables" do
    org_stdout = $stdout
    session = nil

    # This is necessary to avoid the cached RubyRep configurations from getting
    # overwritten by the sync run
    old_config, Initializer.configuration = Initializer.configuration, Configuration.new

    session = Session.new(standard_config)
    session.left.begin_db_transaction
    session.right.begin_db_transaction

    $stdout = StringIO.new
    begin
      sync_runner = SyncRunner.new
      sync_runner.active_printer = ScanReportPrinters::ScanSummaryReporter.new(nil)
      options = {
        :config_file => "#{File.dirname(__FILE__)}/../config/test_config.rb",
        :table_specs => ["scanner_records"]
      }

      sync_runner.execute options

      $stdout.string.should ==
        "scanner_records / scanner_records 5\n"

      left_records = session.left.connection.select_all("select * from scanner_records order by id")
      right_records = session.right.connection.select_all("select * from scanner_records order by id")
      left_records.should == right_records
    ensure
      $stdout = org_stdout
      Initializer.configuration = old_config if old_config
      if session
        session.left.rollback_db_transaction
        session.right.rollback_db_transaction
      end
    end
  end

  it "create_processor should create the TableSync instance" do
    TableSync.should_receive(:new).
      with(:dummy_session, "left_table", "right_table").
      and_return(:dummy_table_sync)
    sync_runner = SyncRunner.new
    sync_runner.create_processor(:dummy_session, "left_table", "right_table").
      should == :dummy_table_sync
  end
end