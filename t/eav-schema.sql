-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

-- -----------------------------------------------------
-- Schema dbix_eav
-- -----------------------------------------------------

-- -----------------------------------------------------
-- Table `eav_entity_types`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_entity_types` ;

CREATE TABLE IF NOT EXISTS `eav_entity_types` (
  `id` INTEGER NOT NULL AUTO_INCREMENT,
  `tenant_id` INTEGER NULL,
  `name` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `name_UNIQUE` (`tenant_id` ASC, `name` ASC))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_entities`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_entities` ;

CREATE TABLE IF NOT EXISTS `eav_entities` (
  `id` INTEGER NOT NULL AUTO_INCREMENT,
  `tenant_id` INTEGER NULL,
  `entity_type_id` INTEGER NOT NULL,
  `created_at` DATETIME NULL,
  `updated_at` DATETIME NULL,
  `is_deleted` TINYINT(1) NULL DEFAULT 0,
  `is_active` TINYINT(1) NULL DEFAULT 1,
  `is_published` TINYINT(1) NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  INDEX `fk_entity_type_id` (`entity_type_id` ASC),
  CONSTRAINT `fk_eav_entities_eav_entity_types1`
    FOREIGN KEY (`entity_type_id`)
    REFERENCES `eav_entity_types` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_attributes`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_attributes` ;

CREATE TABLE IF NOT EXISTS `eav_attributes` (
  `id` INTEGER NOT NULL AUTO_INCREMENT,
  `tenant_id` INTEGER NULL,
  `entity_type_id` INTEGER NOT NULL,
  `name` VARCHAR(64) NULL,
  `data_type` VARCHAR(16) NULL,
  `label` VARCHAR(64) NULL,
  `max_length` INT NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_entity_type_id` (`entity_type_id` ASC),
  UNIQUE INDEX `name_UNIQUE` (`entity_type_id` ASC, `name` ASC),
  CONSTRAINT `fk_eav_attributes_eav_entity_types`
    FOREIGN KEY (`entity_type_id`)
    REFERENCES `eav_entity_types` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_value_int`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_value_int` ;

CREATE TABLE IF NOT EXISTS `eav_value_int` (
  `entity_id` INTEGER NOT NULL,
  `attribute_id` INTEGER NOT NULL,
  `value` INT NULL,
  PRIMARY KEY (`entity_id`, `attribute_id`),
  INDEX `fk_eav_value_int_eav_attributes1_idx` (`attribute_id` ASC),
  CONSTRAINT `fk_eav_value_int_eav_entities1`
    FOREIGN KEY (`entity_id`)
    REFERENCES `eav_entities` (`id`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_eav_value_int_eav_attributes1`
    FOREIGN KEY (`attribute_id`)
    REFERENCES `eav_attributes` (`id`)
    ON DELETE RESTRICT
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_value_varchar`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_value_varchar` ;

CREATE TABLE IF NOT EXISTS `eav_value_varchar` (
  `entity_id` INTEGER NOT NULL,
  `attribute_id` INTEGER NOT NULL,
  `value` VARCHAR(255) NULL,
  PRIMARY KEY (`entity_id`, `attribute_id`),
  INDEX `fk_eav_value_varchar_eav_attributes1_idx` (`attribute_id` ASC),
  CONSTRAINT `fk_eav_value_varchar_eav_attributes1`
    FOREIGN KEY (`attribute_id`)
    REFERENCES `eav_attributes` (`id`)
    ON DELETE RESTRICT
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_eav_value_varchar_eav_entities1`
    FOREIGN KEY (`entity_id`)
    REFERENCES `eav_entities` (`id`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_value_text`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_value_text` ;

CREATE TABLE IF NOT EXISTS `eav_value_text` (
  `entity_id` INTEGER NOT NULL,
  `attribute_id` INTEGER NOT NULL,
  `value` TEXT NULL,
  PRIMARY KEY (`entity_id`, `attribute_id`),
  INDEX `fk_eav_value_text_eav_attributes1_idx` (`attribute_id` ASC),
  CONSTRAINT `fk_eav_value_text_eav_attributes1`
    FOREIGN KEY (`attribute_id`)
    REFERENCES `eav_attributes` (`id`)
    ON DELETE RESTRICT
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_eav_value_text_eav_entities1`
    FOREIGN KEY (`entity_id`)
    REFERENCES `eav_entities` (`id`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_value_decimal`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_value_decimal` ;

CREATE TABLE IF NOT EXISTS `eav_value_decimal` (
  `entity_id` INTEGER NOT NULL,
  `attribute_id` INTEGER NOT NULL,
  `value` DECIMAL(10,2) NULL,
  PRIMARY KEY (`entity_id`, `attribute_id`),
  INDEX `fk_eav_value_decimal_eav_attributes1_idx` (`attribute_id` ASC),
  CONSTRAINT `fk_eav_value_decimal_eav_attributes1`
    FOREIGN KEY (`attribute_id`)
    REFERENCES `eav_attributes` (`id`)
    ON DELETE RESTRICT
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_eav_value_decimal_eav_entities1`
    FOREIGN KEY (`entity_id`)
    REFERENCES `eav_entities` (`id`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_value_datetime`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_value_datetime` ;

CREATE TABLE IF NOT EXISTS `eav_value_datetime` (
  `entity_id` INTEGER NOT NULL,
  `attribute_id` INTEGER NOT NULL,
  `value` DATETIME NULL,
  PRIMARY KEY (`entity_id`, `attribute_id`),
  INDEX `fk_eav_value_datetime_eav_attributes1_idx` (`attribute_id` ASC),
  CONSTRAINT `fk_eav_value_datetime_eav_attributes1`
    FOREIGN KEY (`attribute_id`)
    REFERENCES `eav_attributes` (`id`)
    ON DELETE RESTRICT
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_eav_value_datetime_eav_entities1`
    FOREIGN KEY (`entity_id`)
    REFERENCES `eav_entities` (`id`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_relationships`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_relationships` ;

CREATE TABLE IF NOT EXISTS `eav_relationships` (
  `id` INTEGER NOT NULL AUTO_INCREMENT,
  `tenant_id` INTEGER NULL,
  `left_entity_type_id` INTEGER NULL,
  `right_entity_type_id` INTEGER NULL,
  `is_belongs_to` TINYINT(1) NOT NULL DEFAULT 0,
  `is_has_one` TINYINT(1) NOT NULL DEFAULT 0,
  `is_has_many` TINYINT(1) NOT NULL DEFAULT 0,
  `is_many_to_many` TINYINT(1) NOT NULL DEFAULT 0,
  `name` VARCHAR(45) NOT NULL,
  `description` VARCHAR(255) NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_left_entity_type_id` (`left_entity_type_id` ASC),
  INDEX `fk_right_entity_type_id` (`right_entity_type_id` ASC),
  CONSTRAINT `fk_eav_entity_relationships_eav_entity_classes1`
    FOREIGN KEY (`left_entity_type_id`)
    REFERENCES `eav_entity_types` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_eav_relationships_eav_entity_classes1`
    FOREIGN KEY (`right_entity_type_id`)
    REFERENCES `eav_entity_types` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_entity_relationships`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_entity_relationships` ;

CREATE TABLE IF NOT EXISTS `eav_entity_relationships` (
  `relationship_id` INTEGER NOT NULL,
  `left_entity_id` INTEGER NOT NULL,
  `right_entity_id` INTEGER NOT NULL,
  PRIMARY KEY (`relationship_id`, `left_entity_id`, `right_entity_id`),
  INDEX `fk_right_entity_id` (`right_entity_id` ASC),
  INDEX `fk_relationship_id` (`relationship_id` ASC),
  CONSTRAINT `fk_eav_entity_relationships_eav_entities1`
    FOREIGN KEY (`left_entity_id`)
    REFERENCES `eav_entities` (`id`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_eav_entity_relationships_eav_entities2`
    FOREIGN KEY (`right_entity_id`)
    REFERENCES `eav_entities` (`id`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_eav_entity_relationships_eav_relationships1`
    FOREIGN KEY (`relationship_id`)
    REFERENCES `eav_relationships` (`id`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_value_boolean`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_value_boolean` ;

CREATE TABLE IF NOT EXISTS `eav_value_boolean` (
  `entity_id` INTEGER NOT NULL,
  `attribute_id` INTEGER NOT NULL,
  `value` TINYINT(1) NULL,
  PRIMARY KEY (`entity_id`, `attribute_id`),
  INDEX `fk_eav_value_boolean_eav_attributes1_idx` (`attribute_id` ASC),
  CONSTRAINT `fk_eav_value_boolean_eav_attributes1`
    FOREIGN KEY (`attribute_id`)
    REFERENCES `eav_attributes` (`id`)
    ON DELETE RESTRICT
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_eav_value_boolean_eav_entities1`
    FOREIGN KEY (`entity_id`)
    REFERENCES `eav_entities` (`id`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `eav_type_hierarchy`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `eav_type_hierarchy` ;

CREATE TABLE IF NOT EXISTS `eav_type_hierarchy` (
  `parent_type_id` INTEGER NOT NULL,
  `child_type_id` INTEGER NOT NULL,
  PRIMARY KEY (`parent_type_id`, `child_type_id`),
  INDEX `fk_eav_class_hierarchy_eav_entity_types2_idx` (`child_type_id` ASC),
  CONSTRAINT `fk_eav_class_hierarchy_eav_entity_types1`
    FOREIGN KEY (`parent_type_id`)
    REFERENCES `eav_entity_types` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_eav_class_hierarchy_eav_entity_types2`
    FOREIGN KEY (`child_type_id`)
    REFERENCES `eav_entity_types` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
