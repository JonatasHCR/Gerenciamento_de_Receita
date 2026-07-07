class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!

  def not_found
    respond_to do |format|
      format.html { render :not_found, status: :not_found, layout: false }
      format.any  { head :not_found }
    end
  end
end
