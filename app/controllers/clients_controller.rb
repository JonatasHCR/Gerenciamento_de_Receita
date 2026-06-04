class ClientsController < ApplicationController
  before_action :set_client, only: [:show, :edit, :update, :destroy]

  def index
    authorize Client
    @clients = policy_scope(Client).order(:name)
  end

  def show
    authorize @client
  end

  def new
    authorize Client
    @client = Client.new
  end

  def create
    authorize Client
    @client = Client.new(client_params)
    if @client.save
      redirect_to @client, notice: "Cliente criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @client
  end

  def update
    authorize @client
    if @client.update(client_params)
      redirect_to @client, notice: "Cliente atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @client
    if @client.destroy
      redirect_to clients_path, notice: "Cliente removido."
    else
      redirect_to @client, alert: "Não é possível remover: possui centros de custo associados."
    end
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :full_name)
  end
end
