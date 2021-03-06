class Analysis
  attr_reader :nested_data, :row_count, :col_count, :student_count, :question_count, :standards, :advisories, :answer_key, :students, :weights_array
  def initialize(raw_data)
    clean_data = raw_data.gsub("\"","")
    @nested_data = clean_data.split("\r\n").collect do |row|
      row.split("\t")
    end
    @row_count = @nested_data.count
    @col_count = @nested_data[0].count
    @student_count = @row_count - 3
    @question_count = @col_count - 5
    @standards = []
    populate_standards
    @advisories = []
    populate_advisories
    @answer_key = []
    populate_answers
    @@weights_array = []
    populate_weights
    @students = []
    create_students
    sort_students_into_advisories
    compute_advisory_standard_performance
    compute_advisory_average
    compute_advisory_grade_level_performance
    compute_overall_averages
    identify_bubble_students
  end

  def compute_overall_averages
    @advisories.each do |advisory|
      sum = 0
      advisory.students.each do |student|
        sum += student.raw_score.to_f
      end
      advisory.overall_average = ((sum / advisory.students.count.to_f) + 0.5).to_i.to_s
    end
  end

  def self.weights_array
    @@weights_array
  end

  def identify_bubble_students
    @advisories.each do |advisory|
      advisory.students.each do |student|
      ## MUST CHECK DEFINITION OF BUBBLE STUDENTS
        if student.raw_score.to_f > 58 && student.raw_score.to_f < 70
          advisory.bubble_students.push(student)
        end
      end
      advisory.bubble_percent = (((advisory.bubble_students.count.to_f/advisory.students.count.to_f)*100)+0.5).to_i.to_s
    end
  end

  def compute_advisory_grade_level_performance
    @advisories.each do |advisory|
      advisory.students.each do |student|
        if student.on_grade_level.downcase == "at grade level"
          advisory.grade_level[:students_at].push(student)
        elsif student.on_grade_level.downcase == "above grade level"
          advisory.grade_level[:students_above].push(student)
        elsif student.on_grade_level.downcase == "below grade level"
          advisory.grade_level[:students_below].push(student)
        else
          puts "Error: #{student.name} did not have a grade level indication."
        end
      end
      advisory.percent_grade_level[:above] = (((advisory.grade_level[:students_above].count.to_f / advisory.students.count.to_f)*100.0) + 0.5).to_i.to_s + "%"
      advisory.percent_grade_level[:at] = (((advisory.grade_level[:students_at].count.to_f / advisory.students.count.to_f)*100.0) + 0.5).to_i.to_s + "%"
      advisory.percent_grade_level[:below] = (((advisory.grade_level[:students_below].count.to_f / advisory.students.count.to_f)*100.0) + 0.5).to_i.to_s + "%"
    end
  end

  def compute_advisory_standard_performance
    @advisories.each do |advisory|
      @standards.each_with_index do |standard, i|
        advisory.standards_breakdown[standard] = []
        advisory.students.each do |student|
          advisory.standards_breakdown[standard].push(student.score_array[i])
        end
      end
    end
  end

  def compute_advisory_average
    @advisories.each do |advisory|
      advisory.standards_breakdown.each do |standard, standard_score_array|
        sum = 0
        standard_score_array.each do |student_score|
          sum += student_score
        end
        average = sum / standard_score_array.count
        advisory.standards_average[standard]=average
        advisory.standards_average.each do |standard, decimal|
          percentage = (decimal * 100.0) + 0.50
          percentage = percentage.to_i.to_s + "%"
          advisory.standards_whole_number_average[standard] = percentage
        end
      end
    end
  end

  def populate_weights
    @question_count.times do |i|
      if @answer_key[i].to_i == 0
        weight = 1
      else
        weight = @answer_key[i].to_i
      end
      @@weights_array.push(weight)
    end
  end

  def populate_answers
    @question_count.times do |i|
      @answer_key.push(@nested_data[2][i+5])
      i += 1
    end
  end

  def populate_standards
    @question_count.times do |i|
      @standards << @nested_data[1][i+5]
    end
  end

  def populate_advisories
    @advisories.push("All students")
    @nested_data.each_with_index do |row, row_number|
      unless row_number < 3 || @advisories.include?(row[2])
        @advisories.push(row[2])
      end
    end
    @advisory_list = []
    @advisories.each do |advisory|
      @advisory_list.push(Advisory.new(advisory))
    end
    @advisories = @advisory_list
  end

  def check_answers(student)
    @question_count.times do |i|
      if @answer_key[i] == student.answers[i]
        score = 1.0
      elsif student.answers[i].to_i > 0
        score = student.answers[i].to_f / @answer_key[i].to_f
      else
        score = 0.0
      end
      student.score_array.push(score)
    end
  end

  def multiple_standards?
    if @standards.count == @standards.uniq.count
      "No standards are duplicated"
    else
      "Some standards are addressed accross multiple questions"
    end
  end

  def create_students
    @student_count.times do |i|
      row = @nested_data[i+3]
      answers = []
      @question_count.times do |j|
        answers.push(@nested_data[i+3][j+5])
      end
      student = Student.new(row, answers)
      check_answers(student)
      @students.push(student)
    end
  end

  def sort_students_into_advisories
    @advisories.each do |advisory|
      @students.each do |student|
        if student.advisory == advisory.name
          advisory.students.push(student)
        end
        if advisory.name == "All students"
          advisory.students.push(student)
        end
      end
    end
  end

end # end of data class - primarily names and sorts data, does not store many results well

class Student
  attr_reader :answers, :name, :advisory, :on_grade_level
  attr_accessor :raw_score, :standards_breakdown, :score_array
  @@list = []
  def initialize(student_row, answers)#, weights_array=Analysis.weights_array)
    @student_row = student_row
    @name = student_row[0]
    @student_id = student_row[1]
    @advisory = student_row[2]
    @standards_breakdown = {}
    @score_array = []
    @raw_score = student_row[3]
    @on_grade_level = student_row[4]
    @answers = answers
    @@list.push(self)
    #@weights_array = weights_array
  end

  def validate_math
    q_sum = 0
    Analysis.weights_array
    @score_array.each_with_index {|x, i| q_sum += x*Analysis.weights_array[i]}
    t_sum = 0
    Analysis.weights_array.each {|x| t_sum += x.to_f}
    weighted_average = q_sum / t_sum
    weighted_average = weighted_average * 100.0 + 0.5
    weighted_average = weighted_average.to_i
    "Schoolrunner says that #{self.name}'s score is #{@raw_score}, Ruby says it's #{weighted_average}%."
  end

  def self.list
    @@list
  end

end #end of student class

class Advisory
  attr_accessor :students, :name, :standards_breakdown, :standards_average, :standards_whole_number_average, :grade_level, :percent_grade_level, :bubble_students, :bubble_percent, :overall_average
  @@list = []
  def initialize(name)
    @name = name
    @students = []
    @standards_breakdown = {}
    @@list.push(self)
    @standards_average = {}
    @standards_whole_number_average = {}
    @grade_level = {
      :students_above => [],
      :students_at => [],
      :students_below => []
    }
    @percent_grade_level = {}
    @bubble_students = []
  end

  def self.list
    @@list
  end

end # end of advisory class
