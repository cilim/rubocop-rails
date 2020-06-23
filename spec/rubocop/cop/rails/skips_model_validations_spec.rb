# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Rails::SkipsModelValidations, :config do
  cop_config = {
    'ForbiddenMethods' => %w[decrement!
                             decrement_counter
                             increment!
                             increment_counter
                             toggle!
                             touch
                             update_all
                             update_attribute
                             update_column
                             update_columns
                             update_counters]
  }

  subject(:cop) { described_class.new(config) }

  let(:msg) { 'Avoid using `%s` because it skips validations.' }
  let(:cop_config) { cop_config }

  methods_with_arguments = described_class::METHODS_WITH_ARGUMENTS

  context 'with default forbidden methods' do
    cop_config['ForbiddenMethods'].each do |method_name|
      it "registers an offense for `#{method_name}`" do
        inspect_source("User.#{method_name}(:attr)")
        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq([format(msg, method_name)])
      end
    end

    it 'accepts FileUtils.touch' do
      expect_no_offenses("FileUtils.touch('file')")
    end

    it 'accepts touch with literal true' do
      expect_no_offenses('belongs_to(:user).touch(true)')
    end

    it 'accepts touch with literal false' do
      expect_no_offenses('belongs_to(:user).touch(false)')
    end
  end

  context 'with methods that require at least an argument' do
    methods_with_arguments.each do |method_name|
      it "doesn't register an offense for `#{method_name}`" do
        expect_no_offenses("User.#{method_name}")
      end
    end
  end

  context "with methods that don't require an argument" do
    (cop_config['ForbiddenMethods'] - methods_with_arguments).each do |method_name|
      it "registers an offense for `#{method_name}`" do
        inspect_source("User.#{method_name}")
        expect(cop.offenses.size).to eq(1)
        expect(cop.messages)
          .to eq([format(msg, method_name)])
      end
    end
  end

  context 'with `update_attribute` method in forbidden methods' do
    let(:cop_config) do
      { 'ForbiddenMethods' => %w[update_attribute] }
    end

    allowed_methods = cop_config['ForbiddenMethods'].reject do |val|
      val == 'update_attribute'
    end

    allowed_methods.each do |method_name|
      it "accepts `#{method_name}`" do
        expect_no_offenses("User.#{method_name}")
      end
    end

    it 'registers an offense for `update_attribute`' do
      expect_offense(<<~RUBY)
        user.update_attribute(:website, 'example.com')
             ^^^^^^^^^^^^^^^^ Avoid using `update_attribute` because it skips validations.
      RUBY
    end

    context 'when using safe navigation operator' do
      it 'registers an offense for `update_attribute`' do
        expect_offense(<<~RUBY)
          user&.update_attribute(:website, 'example.com')
                ^^^^^^^^^^^^^^^^ Avoid using `update_attribute` because it skips validations.
        RUBY
      end
    end
  end

  context 'with allowed methods' do
    let(:cop_config) do
      {
        'ForbiddenMethods' => %w[toggle! touch],
        'AllowedMethods' => %w[touch]
      }
    end

    it 'registers an offense for method not in allowed methods' do
      expect_offense(<<~RUBY)
        user.toggle!(:active)
             ^^^^^^^ Avoid using `toggle!` because it skips validations.
      RUBY
    end

    context 'when using safe navigation operator' do
      it 'registers an offense for method not in allowed methods' do
        expect_offense(<<~RUBY)
          user&.toggle!(:active)
                ^^^^^^^ Avoid using `toggle!` because it skips validations.
        RUBY
      end
    end

    it 'accepts method in allowed methods, superseding the forbidden methods' do
      expect_no_offenses('User.touch(:attr)')
    end
  end
end
