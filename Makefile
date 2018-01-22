build:
	@docker build -t codereviewvideos/php-7 .

push:
	@docker push codereviewvideos/php7

bp: build push
