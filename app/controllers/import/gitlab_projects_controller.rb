class Import::GitlabProjectsController < Import::BaseController
  before_action :verify_gitlab_project_import_enabled
  before_action :verify_project_and_namespace_access

  def new
    @namespace_id = project_params[:namespace_id]
    @path = project_params[:path]
  end

  def create
    unless file_is_valid?
      return redirect_back_or_default(options: { alert: "You need to upload a GitLab project export archive." })
    end

    @project = Project.create_from_import_job(current_user_id: current_user.id,
                                              tmp_file: File.expand_path(params[:file].path),
                                              namespace_id: project_params[:namespace_id],
                                              project_path: project_params[:path])

    @project = Gitlab::GitlabImport::ProjectCreator.new(repo, namespace, current_user, access_params).execute

    flash[:notice] = "The project import has been started."

    if @project.saved?
      redirect_to(
        project_path(@project),
        notice: "Project '#{@project.name}' is being imported."
      )
    else
      render 'new'
    end
  end

  private

  def file_is_valid?
    params[:file].respond_to?(:read) && params[:file].content_type == 'application/x-gzip'
  end

  def verify_project_and_namespace_access
    unless namespace_access?
      render_403
    end
  end

  def namespace_access?
    can?(current_user, :create_projects, Namespace.find(project_params[:namespace_id]))
  end

  def verify_gitlab_project_import_enabled
    render_404 unless gitlab_project_import_enabled?
  end

  def project_params
    params.permit(
      :path, :namespace_id,
    )
  end
end
