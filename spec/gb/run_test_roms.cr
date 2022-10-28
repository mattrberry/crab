require "option_parser"

TEST_RESULTS_DIR = "spec/gb/test_results"
SCREENSHOT_DIR   = "#{TEST_RESULTS_DIR}/screenshots"
README_FILE      = "#{TEST_RESULTS_DIR}/README.md"

# kill process after given number of seconds
def kill(process : Process, after : Number = 5) : Nil
  spawn do
    sleep after
    process.signal Signal::KILL if process.exists?
  end
end

def get_test_name(dir : String, test : String) : String
  test.rpartition('.')[0][dir.size + 1, test.size]
end

alias TestResult = NamedTuple(test: String, pass: Bool)
alias TestSuite = NamedTuple(suite: String, results: Array(TestResult))

test_results : Array(TestSuite) = [] of TestSuite

acid_dir = ""
blargg_dir = ""
mealybug_dir = ""
mooneye_dir = ""

OptionParser.parse do |parser|
  parser.on("--acid PATH", "Path to directory with acid tests") { |path| acid_dir = path }
  parser.on("--blargg PATH", "Path to directory with blargg tests") { |path| blargg_dir = path }
  parser.on("--mealybug PATH", "Path to directory with mealybug tests") { |path| mealybug_dir = path }
  parser.on("--mooneye PATH", "Path to directory with mooneye tests") { |path| mooneye_dir = path }
  parser.invalid_option { abort parser }
end

system "shards build -Dgraphics_test > /dev/null"

unless acid_dir == ""
  [true, false].each do |fifo|
    test_results << {suite: "Acid#{" Fifo" if fifo}", results: [] of TestResult}
    puts "Acid #{"Fifo " if fifo}Tests"
    Dir.glob("#{acid_dir}/*acid2.gb*").sort.each do |path|
      test_name = get_test_name acid_dir, path
      Process.run "bin/crab", [path, "--headless"] + (fifo ? ["--fifo"] : ["--scanline"] of String) do |process|
        kill process, after: 1
      end
      system %[touch out.png] # touch image in case something went wrong
      system %[mv out.png #{SCREENSHOT_DIR}/#{test_name}#{"_fifo" if fifo}.png]
      system %[compare -metric AE #{SCREENSHOT_DIR}/#{test_name}#{"_fifo" if fifo}.png #{SCREENSHOT_DIR}/expected/#{test_name}.png /tmp/crab_diff 2>/dev/null]
      passed = $?.exit_status == 0
      test_results[test_results.size - 1][:results] << {test: test_name, pass: passed}
      print passed ? "." : "F"
    end
    print "\n"
  end
end

unless mealybug_dir == ""
  test_results << {suite: "Mealybug Fifo", results: [] of TestResult}
  puts "Mealybug Fifo Tests"
  Dir.glob("#{mealybug_dir}/**/*.gb").sort.each do |path|
    test_name = get_test_name mealybug_dir, path
    Process.run "bin/crab", [path, "--headless", "--fifo"] do |process|
      kill process, after: 1
    end
    system %[touch out.png] # touch image in case something went wrong
    system %[mv out.png #{SCREENSHOT_DIR}/#{test_name}.png]
    system %[compare -metric AE #{SCREENSHOT_DIR}/#{test_name}.png #{SCREENSHOT_DIR}/expected/#{test_name}.png /tmp/crab_diff 2>/dev/null]
    passed = $?.exit_status == 0
    test_results[test_results.size - 1][:results] << {test: test_name, pass: passed}
    print passed ? "." : "F"
  end
  print "\n"
end

system "shards build -Dprint_serial > /dev/null"

unless mooneye_dir == ""
  test_results << {suite: "Mooneye", results: [] of TestResult}
  puts "Mooneye Tests"
  fib_string = "358132134"
  Dir.glob("#{mooneye_dir}/**/*.gb").sort.each do |path|
    next if path.includes?("util") || path.includes?("manual-only") || path.includes?("dmg") || path.includes?("mgb") || path.includes?("sgb")
    test_name = get_test_name mooneye_dir, path
    passed = false
    Process.run("bin/crab", [path, "--headless", "--scanline"]) do |process|
      kill process, after: 10 # seconds
      result = process.output.gets 9
      process.terminate if process.exists?
      passed = result == fib_string
    end
    test_results[test_results.size - 1][:results] << {test: test_name, pass: passed}
    print passed ? "." : "F"
  end
  print "\n"
end

File.open README_FILE, "w" do |file|
  file.puts "# Test Results"
  test_results.each do |test_suite|
    file.puts "## #{test_suite[:suite]} Tests"
    file.puts "| Result | Test Name |"
    file.puts "|--------|-----------|"
    test_suite[:results].each do |test_result|
      file.puts "| #{test_result[:pass] ? "👌" : "👀"} | #{test_result[:test]} |"
    end
  end
end
