build:
	@docker build -t codereviewvideos/php-7 .

push:
	@docker push codereviewvideos/php-7

bp: build push
