require 'spec_helper'

describe Dynamini::BatchOperations do

  let(:model_attributes) {
    {
        name: 'Widget',
        price: 9.99,
        id: 'abcd1234',
        hash_key: '009'
    }
  }

  let(:model) { Dynamini::Base.new(model_attributes) }

  subject { Dynamini::Base }

  describe '.import' do
    it 'should generate timestamps for each model' do
      expect_any_instance_of(subject).to receive(:generate_timestamps!).twice
      subject.import([model, model])
    end

    it 'should call .dynamo_batch_save with batches of 25 models' do
      models = Array.new(30, model)
      expect(subject).to receive(:dynamo_batch_save).with(array_including(models[0..24])).ordered
      expect(subject).to receive(:dynamo_batch_save).with(array_including(models[25..29])).ordered
      subject.import(models)
    end
  end

  describe '.dynamo_batch_save' do
    before do
      Dynamini::Base.set_range_key(nil)
    end

    it 'should batch write the models to dynamo' do
      model2 = Dynamini::Base.new(id: '123')
      model3 = Dynamini::Base.new(id: '456')
      Dynamini::Base.dynamo_batch_save([model2, model3])
      expect(Dynamini::Base.find('123')).to_not be_nil
      expect(Dynamini::Base.find('456')).to_not be_nil
    end
  end

  describe '.batch_find' do
    before do
      model.save
    end
    context 'when requesting 0 items' do
      it 'should return an empty array' do
        expect(Dynamini::Base.batch_find).to eq []
      end
    end
    context 'when requesting 2 items' do
      it 'should return a 2-length array containing each item' do
        Dynamini::Base.create(id: '4321')
        objects = Dynamini::Base.batch_find(['abcd1234', '4321'])
        expect(objects.length).to eq 2
        expect(objects.first.id).to eq model.id
        expect(objects.last.id).to eq '4321'
      end
    end
    context 'when requesting too many items' do
      it 'should raise an error' do
        a = []
        150.times { a << 'foo' }
        expect { Dynamini::Base.batch_find(a) }.to raise_error StandardError
      end
    end
  end

end

