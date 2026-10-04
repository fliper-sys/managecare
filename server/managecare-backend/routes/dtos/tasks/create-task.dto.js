const joi = require("joi");

const createTaskSchema = joi.object({
  title: joi.string().required(),
  review: joi.string().optional(),
  dueDate: joi.date().required()
});

module.exports = {
  createTaskSchema,
};