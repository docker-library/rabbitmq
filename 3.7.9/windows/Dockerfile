FROM mcr.microsoft.com/windows/servercore:1803

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV RABBITMQ_HOME C:\RabbitMQ

# PATH isn't actually set in the Docker image, so we have to set it from within the container
RUN $newPath = ('C:\erl\bin;{0}\sbin;{1}' -f $env:RABBITMQ_HOME, $env:PATH); \
	Write-Host ('Updating PATH: {0}' -f $newPath); \
	setx /M PATH $newPath
# doing this first to share cache across versions more aggressively

# no minor updates for Windows -- infeasible to rebuild from source
ENV OTP_VERSION 21.2

# pulling from erlang-solutions.com instead of erlang.org because it's a lot faster download and includes https
RUN $url = 'https://packages.erlang-solutions.com/erlang/esl-erlang/FLAVOUR_1_general/esl-erlang_{0}~windows_amd64.exe' -f $env:OTP_VERSION; \
	Write-Host ('Downloading {0} ...' -f $url); \
	Invoke-WebRequest -Uri $url -OutFile otp-setup.exe; \
	\
	Write-Host 'Installing ...'; \
	Start-Process otp-setup.exe -Wait \
		-ArgumentList @( \
# https://nsis.sourceforge.io/Which_command_line_parameters_can_be_used_to_configure_installers
			'/S', \
			'/D=C:\erl' \
		); \
	\
	Write-Host 'Removing ...'; \
	Remove-Item otp-setup.exe -Force; \
	\
	Write-Host 'Validating ...'; \
	Start-Process erl -NoNewWindow -Wait \
		-ArgumentList @( \
			'-version' \
		); \
	\
	Write-Host 'Complete.'

ENV RABBITMQ_VERSION 3.7.10

# https://www.rabbitmq.com/install-windows-manual.html
RUN $url = 'https://github.com/rabbitmq/rabbitmq-server/releases/download/v{0}/rabbitmq-server-windows-{0}.zip' -f $env:RABBITMQ_VERSION; \
	Write-Host ('Downloading {0} ...' -f $url); \
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
	Invoke-WebRequest -Uri $url -OutFile rabbit.zip; \
	\
	Write-Host 'Expanding ...'; \
	Expand-Archive -Path rabbit.zip -DestinationPath C:\; \
	\
	Write-Host 'Renaming ...'; \
	Move-Item -LiteralPath ('rabbitmq_server-{0}' -f $env:RABBITMQ_VERSION) -Destination $env:RABBITMQ_HOME; \
	\
	Write-Host 'Removing ...'; \
	Remove-Item rabbit.zip -Force; \
	\
# TODO verification
	\
	Write-Host 'Complete.'

# send all logs to TTY
ENV RABBITMQ_LOGS=- RABBITMQ_SASL_LOGS=-

# TODO RABBITMQ_DATA_DIR

# TODO CMD ["rabbitmq-server"]
CMD ["powershell"]
