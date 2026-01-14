terraform {
  backend "http" {
    address        = var.http_address
    lock_address   = var.http_lock_address
    unlock_address = var.http_lock_address
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5

  }
}
