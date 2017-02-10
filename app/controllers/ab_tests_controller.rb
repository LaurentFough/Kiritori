# frozen_string_literal: true
class AbTestsController < ApplicationController

  def index
    @ab_tests = AbTest.all
  end

  def new
    @ab_test = AbTest.new
  end

  def create
    ab_test = AbTest.new(ab_test_params, delete_flag: 0)
    ab_test.update(weight: params['weight'].to_s)
    if ab_test.save
      flash[:success] = '保存に成功にしました。'
      export_config(ab_test)
    else
      flash[:danger] = '保存に失敗しました'
    end
    redirect_to action: :index
  end

  def edit
    @ab_test = AbTest.find(params[:id])
  end

  def update
    ab_test = AbTest.find(params[:format])
    ab_test.update(ab_test_params)
    ab_test.update(weight: params['weight'].to_s)
    if ab_test.save
      msg = '保存に成功にしました。'
      redirect_to action: :index
    else
      msg = '保存に失敗しました'
      redirect_to action: :edit, id: params[:id]
    end
  end
  def destroy
    ab_test = AbTest.find(params[:id])
    msg = ab_test.destroy ? 'Delete Success!' : flash[:danger] = 'Save Failed.'
    redirect_to({action: 'index'}, flash: { success: msg })
  end

  def rebuild
    ab_test = AbTest.find(params[:id])
    msg = export_config(ab_test) ? 'Rebuild Success!' : 'Save Failed.'
    redirect_to action: 'index'
  end

  def enable_haproxy
    ab_test = AbTest.find(params[:id])
    system("sudo ln -fs /usr/local/app/Kiritori/haproxy/haproxy_#{ab_test.branch}.cfg /etc/haproxy/haproxy.cfg && sudo service haproxy reload")
    redirect_to({action: 'index'}, flash: { success: 'success' })
  end

  private

  def ab_test_params
    params.require(:ab_test).permit(:id, :branch, :description, :ended_at, :delete_flag)
  end

  def export_config(ab_test)
    config_hash = ab_test.attributes
    weight = config_hash['weight'].split(',').map { |m| m.delete('[]"\\\\') }
    return false if weight.first.to_i.zero? || weight[1].to_i.zero?

    config_hash['normal_weight'] = (weight.first.to_i / Rails.application.config.normal_app_host.size + Rails.application.config.ab_app_host.size).floor
    config_hash['ab_weight'] = weight[1].lstrip

    haproxy_config = Slim::Template.new(Rails.root.join('app', 'controllers', 'concerns', 'haproxy.cfg.slim'))
                                   .render(self, config_hash)
    File.open(Rails.root.join('haproxy', "haproxy_#{ab_test.branch}.cfg"), 'w') do |f|
      f.write(haproxy_config)
    end
  end
end
