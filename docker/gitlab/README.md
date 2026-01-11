# GitLab Docker Setup

This directory contains the necessary files to set up GitLab using Docker
and Docker Compose. The setup includes a `gitlab.yaml` file that defines the
GitLab service configuration.

## Adding gitlab runner as docker container

To add a GitLab runner as a Docker container, follow these steps:

1. SSH into the target machine where you want to run the GitLab runner.
2. Make sure Docker and Docker Compose are installed on the machine.
3. Obtain the GitLab runner registration token from your GitLab instance.
   You can find this token in the GitLab web interface under
   `Settings > CI/CD > Runners > Create Instance Runner > Registration Token`.
4. Then run the following command to start the GitLab runner container. There
   can be multiple gitlab runners commisioned the same way by changing the name
   of the container.

   ```bash
   docker volume create gitlab-runner-config-2
   docker run -d \
   --name gitlab-runner-2 \
   --restart always \
   -v gitlab-runner-config-2:/etc/gitlab-runner \
   -v /var/run/docker.sock:/var/run/docker.sock \
   gitlab/gitlab-runner:latest


   docker exec -it gitlab-runner-2 \
   gitlab-runner register \
   --non-interactive \
   --url "https://<gitlab_instance_url>/" \
   --token "<gitlab-runner-registration-token>" \
   --executor "docker" \
   --docker-image alpine:latest \
   --description "docker-runner 2"
   ```

## Troubleshooting

- If the URL returns a 404 error, it is usually gitlab container takes long time
  to start. Please wait for few minutes and try again. If the problem persists,
  check the traefik labels and access logs for more information.

- The initial root password is set in the `gitlab.yaml` file under the
  `GITLAB_ROOT_PASSWORD` environment variable. Make sure to change it to a
  secure password after the first login. If for some reason it does not work.
  You can reset it via the following commands:

  1. Access the GitLab container's shell:
     ```
     docker exec -it <gitlab_container_name> /bin/bash
     ```
  2. Run the following command to reset the root password:
     ```
     gitlab-rails console
     ```
  3. In the Rails console, execute the following commands:
     ```ruby
     user = User.find_by_username('root')
     user.password = 'NewSecurePassword123!'
     user.password_confirmation == 'NewSecurePassword123!'
     user.save!
     ```
  4. Exit the Rails console and the container shell.

- If while disabling signup you get server (500) error, please follow the below
  steps:
  1. Access the GitLab container's shell:
     ```
     docker exec -it <gitlab_container_name> /bin/bash
     ```
  2. Run the following command to open the Rails console:
     ```
     gitlab-rails console
     ```
  3. In the Rails console, execute the following command to disable user signup:
     ```ruby
     settings = ApplicationSetting.last
     settings.update_column(:runners_registration_token_encrypted, nil)
     ```
  4. Exit the Rails console and the container shell.
